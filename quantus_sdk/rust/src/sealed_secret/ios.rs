//! The iOS keychain as the sealed store: one generic password per slot, whose
//! access control the Secure Enclave evaluates on every read. Reached through
//! Security.framework's C API so the bytes never pass through a Swift or Dart
//! string, neither of which can be wiped.
//!
//! The item is `WhenPasscodeSetThisDeviceOnly` and never synchronizable. Its
//! account attribute names its policy, so [`stored`] is answered from
//! attributes alone, which iOS gives without a prompt.

use super::{enrolment, refusal, Failure, Refusal, SealPolicy, POLICIES};
use crate::sensitive::SensitiveVec;
use std::ffi::{c_char, c_void, CStr};
use std::ptr;

type CFTypeRef = *const c_void;
type Id = *mut c_void;

const SUCCESS: i32 = 0;
/// `errSecUserCanceled`
const USER_CANCELED: i32 = -128;
/// `errSecAuthFailed`
const AUTH_FAILED: i32 = -25293;
/// `errSecItemNotFound`
const ITEM_NOT_FOUND: i32 = -25300;
const UTF8: u32 = 0x0800_0100;

impl SealPolicy {
    /// `kSecAccessControlBiometryCurrentSet` or `kSecAccessControlDevicePasscode`.
    fn access_control(self) -> usize {
        match self {
            SealPolicy::Biometry => 1 << 3,
            SealPolicy::DevicePasscode => 1 << 4,
        }
    }

    /// `LAPolicyDeviceOwnerAuthenticationWithBiometrics` or
    /// `LAPolicyDeviceOwnerAuthentication`.
    fn owner_check(self) -> isize {
        match self {
            SealPolicy::Biometry => 1,
            SealPolicy::DevicePasscode => 2,
        }
    }
}

#[repr(C)]
struct Opaque {
    _private: [u8; 0],
}

#[link(name = "CoreFoundation", kind = "framework")]
#[allow(non_upper_case_globals)]
extern "C" {
    static kCFTypeDictionaryKeyCallBacks: Opaque;
    static kCFTypeDictionaryValueCallBacks: Opaque;
    static kCFBooleanTrue: CFTypeRef;
    static kCFBooleanFalse: CFTypeRef;
    static kCFAllocatorNull: CFTypeRef;
    fn CFDictionaryCreate(
        allocator: CFTypeRef,
        keys: *const CFTypeRef,
        values: *const CFTypeRef,
        count: isize,
        key_callbacks: *const Opaque,
        value_callbacks: *const Opaque,
    ) -> CFTypeRef;
    fn CFDataCreateWithBytesNoCopy(
        allocator: CFTypeRef,
        bytes: *const u8,
        length: isize,
        bytes_deallocator: CFTypeRef,
    ) -> CFTypeRef;
    fn CFDataGetBytePtr(data: CFTypeRef) -> *const u8;
    fn CFDataGetLength(data: CFTypeRef) -> isize;
    fn CFStringCreateWithBytes(
        allocator: CFTypeRef,
        bytes: *const u8,
        length: isize,
        encoding: u32,
        is_external_representation: u8,
    ) -> CFTypeRef;
    fn CFRelease(object: CFTypeRef);
}

#[link(name = "Security", kind = "framework")]
#[allow(non_upper_case_globals)]
extern "C" {
    static kSecClass: CFTypeRef;
    static kSecClassGenericPassword: CFTypeRef;
    static kSecAttrService: CFTypeRef;
    static kSecAttrAccount: CFTypeRef;
    static kSecAttrAccessControl: CFTypeRef;
    static kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly: CFTypeRef;
    static kSecAttrSynchronizable: CFTypeRef;
    static kSecValueData: CFTypeRef;
    static kSecReturnData: CFTypeRef;
    static kSecMatchLimit: CFTypeRef;
    static kSecMatchLimitOne: CFTypeRef;
    static kSecUseOperationPrompt: CFTypeRef;
    fn SecAccessControlCreateWithFlags(
        allocator: CFTypeRef,
        protection: CFTypeRef,
        flags: usize,
        error: *mut CFTypeRef,
    ) -> CFTypeRef;
    fn SecItemAdd(attributes: CFTypeRef, result: *mut CFTypeRef) -> i32;
    fn SecItemCopyMatching(query: CFTypeRef, result: *mut CFTypeRef) -> i32;
    fn SecItemDelete(query: CFTypeRef) -> i32;
}

#[link(name = "LocalAuthentication", kind = "framework")]
extern "C" {}

#[link(name = "objc")]
extern "C" {
    fn objc_getClass(name: *const c_char) -> Id;
    fn sel_registerName(name: *const c_char) -> Id;
    fn objc_msgSend();
    fn objc_autoreleasePoolPush() -> *mut c_void;
    fn objc_autoreleasePoolPop(pool: *mut c_void);
}

fn platform(detail: impl ToString) -> Refusal {
    refusal(Failure::Platform, detail)
}

fn keychain(status: i32) -> Refusal {
    let failure = match status {
        USER_CANCELED => Failure::Cancelled,
        AUTH_FAILED => Failure::NotRecognised,
        ITEM_NOT_FOUND => Failure::Missing,
        _ => Failure::Platform,
    };
    refusal(failure, format!("Keychain status {status}"))
}

fn check(status: i32) -> Result<(), Refusal> {
    if status == SUCCESS {
        Ok(())
    } else {
        Err(keychain(status))
    }
}

/// A CoreFoundation object this module created, released on drop.
struct Owned(CFTypeRef);

impl Owned {
    fn new(object: CFTypeRef) -> Result<Self, Refusal> {
        if object.is_null() {
            return Err(platform("CoreFoundation could not create an object"));
        }
        Ok(Self(object))
    }
}

impl Drop for Owned {
    fn drop(&mut self) {
        unsafe { CFRelease(self.0) }
    }
}

fn string(text: &str) -> Result<Owned, Refusal> {
    Owned::new(unsafe {
        CFStringCreateWithBytes(ptr::null(), text.as_ptr(), text.len() as isize, UTF8, 0)
    })
}

/// A query for the item of `slot`, of one policy or of any, plus `extra`.
/// The dictionary retains what it holds.
fn item(
    slot: &str,
    policy: Option<SealPolicy>,
    extra: &[(CFTypeRef, CFTypeRef)],
) -> Result<Owned, Refusal> {
    let service = string(slot)?;
    let account = policy.map(|policy| string(policy.name())).transpose()?;
    let mut pairs = unsafe {
        vec![
            (kSecClass, kSecClassGenericPassword),
            (kSecAttrService, service.0),
        ]
    };
    if let Some(account) = &account {
        pairs.push((unsafe { kSecAttrAccount }, account.0));
    }
    pairs.extend_from_slice(extra);
    let keys: Vec<CFTypeRef> = pairs.iter().map(|pair| pair.0).collect();
    let values: Vec<CFTypeRef> = pairs.iter().map(|pair| pair.1).collect();
    Owned::new(unsafe {
        CFDictionaryCreate(
            ptr::null(),
            keys.as_ptr(),
            values.as_ptr(),
            keys.len() as isize,
            &kCFTypeDictionaryKeyCallBacks,
            &kCFTypeDictionaryValueCallBacks,
        )
    })
}

/// Asks LocalAuthentication whether the owner can be authenticated the way
/// `policy` needs, and reads its answer with
/// [`enrolment::local_authentication`].
pub(crate) fn enforces(policy: SealPolicy) -> Result<bool, Refusal> {
    unsafe {
        let class = objc_getClass(c"LAContext".as_ptr());
        if class.is_null() {
            return Err(platform("LocalAuthentication is not linked"));
        }
        let send = objc_msgSend as unsafe extern "C" fn();
        let create: unsafe extern "C" fn(Id, Id) -> Id = std::mem::transmute(send);
        let can_evaluate: unsafe extern "C" fn(Id, Id, isize, *mut Id) -> bool =
            std::mem::transmute(send);
        let integer: unsafe extern "C" fn(Id, Id) -> isize = std::mem::transmute(send);
        let release: unsafe extern "C" fn(Id, Id) = std::mem::transmute(send);

        let pool = objc_autoreleasePoolPush();
        let context = create(class, selector(c"new"));
        let mut error: Id = ptr::null_mut();
        let able = can_evaluate(
            context,
            selector(c"canEvaluatePolicy:error:"),
            policy.owner_check(),
            &mut error,
        );
        let code = if error.is_null() {
            0
        } else {
            integer(error, selector(c"code"))
        };
        let biometry = integer(context, selector(c"biometryType"));
        release(context, selector(c"release"));
        objc_autoreleasePoolPop(pool);
        enrolment::local_authentication(policy, able, code, biometry)
    }
}

fn selector(name: &CStr) -> Id {
    unsafe { sel_registerName(name.as_ptr()) }
}

pub(crate) fn stored(slot: &str) -> Result<Option<SealPolicy>, Refusal> {
    for policy in POLICIES {
        match unsafe { SecItemCopyMatching(item(slot, Some(policy), &[])?.0, ptr::null_mut()) } {
            SUCCESS => return Ok(Some(policy)),
            ITEM_NOT_FOUND => {}
            status => return Err(keychain(status)),
        }
    }
    Ok(None)
}

/// The data object borrows `secret`, so no copy of it is left in this process.
pub(crate) fn store(slot: &str, secret: &[u8], policy: SealPolicy) -> Result<(), Refusal> {
    delete(slot)?;
    let mut error: CFTypeRef = ptr::null();
    let access = unsafe {
        SecAccessControlCreateWithFlags(
            ptr::null(),
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            policy.access_control(),
            &mut error,
        )
    };
    if !error.is_null() {
        unsafe { CFRelease(error) };
    }
    let access = Owned::new(access)?;
    let data = Owned::new(unsafe {
        CFDataCreateWithBytesNoCopy(
            ptr::null(),
            secret.as_ptr(),
            secret.len() as isize,
            kCFAllocatorNull,
        )
    })?;
    let attributes = unsafe {
        item(
            slot,
            Some(policy),
            &[
                (kSecAttrAccessControl, access.0),
                (kSecAttrSynchronizable, kCFBooleanFalse),
                (kSecValueData, data.0),
            ],
        )?
    };
    check(unsafe { SecItemAdd(attributes.0, ptr::null_mut()) })
}

/// The passcode sheet and Touch ID show `prompt`; Face ID shows no text. The
/// keychain hands back an immutable buffer, which is copied and released
/// without being wiped; the copy returned wipes itself on drop.
pub(crate) fn read(slot: &str, prompt: &str) -> Result<SensitiveVec<u8>, Refusal> {
    let reason = string(prompt)?;
    let query = unsafe {
        item(
            slot,
            None,
            &[
                (kSecReturnData, kCFBooleanTrue),
                (kSecMatchLimit, kSecMatchLimitOne),
                (kSecUseOperationPrompt, reason.0),
            ],
        )?
    };
    let mut result: CFTypeRef = ptr::null();
    check(unsafe { SecItemCopyMatching(query.0, &mut result) })?;
    let data = Owned::new(result)?;
    let released = unsafe {
        std::slice::from_raw_parts(CFDataGetBytePtr(data.0), CFDataGetLength(data.0) as usize)
    };
    Ok(SensitiveVec(released.to_vec()))
}

pub(crate) fn delete(slot: &str) -> Result<(), Refusal> {
    match unsafe { SecItemDelete(item(slot, None, &[])?.0) } {
        SUCCESS | ITEM_NOT_FOUND => Ok(()),
        status => Err(keychain(status)),
    }
}
