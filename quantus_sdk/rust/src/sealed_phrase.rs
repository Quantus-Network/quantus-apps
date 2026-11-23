//! The sealed recovery phrase: one keychain item iOS releases only after a
//! biometric match, on this device only, while a passcode is set. Reached
//! through Security.framework's C API so the bytes never pass through a Swift
//! or Dart string, both of which cannot be wiped.
//!
//! Every read prompts: the item's access control is evaluated by the Secure
//! Enclave, and no authentication context is reused between calls.

/// `errSecUnimplemented`: what every call answers where there is no sealed store.
pub(crate) const UNIMPLEMENTED: i32 = -4;
/// `errSecUserCanceled`: the biometric prompt was dismissed.
pub(crate) const USER_CANCELED: i32 = -128;
/// `errSecAuthFailed`: no match, or biometrics are locked out.
pub(crate) const AUTH_FAILED: i32 = -25293;
/// `errSecItemNotFound`: never stored, or destroyed by iOS when the passcode
/// was turned off or the enrolled biometrics changed.
pub(crate) const ITEM_NOT_FOUND: i32 = -25300;

#[cfg(target_os = "ios")]
pub(crate) use ios::{delete, exists, read, store};
#[cfg(not(target_os = "ios"))]
pub(crate) use unsupported::{delete, exists, read, store};

#[cfg(not(target_os = "ios"))]
mod unsupported {
    use super::UNIMPLEMENTED;
    use crate::sensitive::SensitiveVec;

    pub(crate) fn exists() -> Result<bool, i32> {
        Err(UNIMPLEMENTED)
    }

    pub(crate) fn store(_phrase: &[u8]) -> Result<(), i32> {
        Err(UNIMPLEMENTED)
    }

    pub(crate) fn read() -> Result<SensitiveVec<u8>, i32> {
        Err(UNIMPLEMENTED)
    }

    pub(crate) fn delete() -> Result<(), i32> {
        Err(UNIMPLEMENTED)
    }
}

#[cfg(target_os = "ios")]
#[allow(non_upper_case_globals)]
mod ios {
    use super::ITEM_NOT_FOUND;
    use crate::sensitive::{wipe, SensitiveVec};
    use std::ffi::c_void;
    use std::ptr;

    type CFTypeRef = *const c_void;

    const SERVICE: &str = "quantus_cold_phrase";
    const ACCOUNT: &str = "recovery_phrase";
    const SUCCESS: i32 = 0;
    /// `errSecAllocate`: a CoreFoundation object could not be created.
    const ALLOCATE: i32 = -108;
    const UTF8: u32 = 0x0800_0100;
    /// `kSecAccessControlBiometryCurrentSet`: a match against the biometrics
    /// enrolled now, with no passcode fallback; enrolling another invalidates the item.
    const BIOMETRY_CURRENT_SET: usize = 1 << 3;

    #[repr(C)]
    struct Opaque {
        _private: [u8; 0],
    }

    #[link(name = "CoreFoundation", kind = "framework")]
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

    /// A CoreFoundation object this module created, released on drop.
    struct Owned(CFTypeRef);

    impl Owned {
        fn new(object: CFTypeRef) -> Result<Self, i32> {
            if object.is_null() {
                return Err(ALLOCATE);
            }
            Ok(Self(object))
        }
    }

    impl Drop for Owned {
        fn drop(&mut self) {
            unsafe { CFRelease(self.0) }
        }
    }

    fn string(text: &str) -> Result<Owned, i32> {
        Owned::new(unsafe {
            CFStringCreateWithBytes(ptr::null(), text.as_ptr(), text.len() as isize, UTF8, 0)
        })
    }

    /// The item's identity plus `extra`. The dictionary retains what it holds.
    fn item(extra: &[(CFTypeRef, CFTypeRef)]) -> Result<Owned, i32> {
        let service = string(SERVICE)?;
        let account = string(ACCOUNT)?;
        let identity = unsafe {
            [
                (kSecClass, kSecClassGenericPassword),
                (kSecAttrService, service.0),
                (kSecAttrAccount, account.0),
            ]
        };
        let pairs = identity.iter().chain(extra);
        let keys: Vec<CFTypeRef> = pairs.clone().map(|pair| pair.0).collect();
        let values: Vec<CFTypeRef> = pairs.map(|pair| pair.1).collect();
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

    fn check(status: i32) -> Result<(), i32> {
        if status == SUCCESS {
            Ok(())
        } else {
            Err(status)
        }
    }

    /// By attributes only, which iOS answers without a prompt.
    pub(crate) fn exists() -> Result<bool, i32> {
        match unsafe { SecItemCopyMatching(item(&[])?.0, ptr::null_mut()) } {
            SUCCESS => Ok(true),
            ITEM_NOT_FOUND => Ok(false),
            status => Err(status),
        }
    }

    /// Replaces any item already there. Writing never prompts. The data object
    /// borrows `phrase`, so no copy of it is left behind in this process.
    pub(crate) fn store(phrase: &[u8]) -> Result<(), i32> {
        delete()?;
        let mut error: CFTypeRef = ptr::null();
        let access = unsafe {
            SecAccessControlCreateWithFlags(
                ptr::null(),
                kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                BIOMETRY_CURRENT_SET,
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
                phrase.as_ptr(),
                phrase.len() as isize,
                kCFAllocatorNull,
            )
        })?;
        let attributes = unsafe {
            item(&[
                (kSecAttrAccessControl, access.0),
                (kSecAttrSynchronizable, kCFBooleanFalse),
                (kSecValueData, data.0),
            ])?
        };
        check(unsafe { SecItemAdd(attributes.0, ptr::null_mut()) })
    }

    /// Blocks on the biometric prompt. The keychain's own buffer is wiped
    /// before it is released; the copy returned wipes itself on drop.
    pub(crate) fn read() -> Result<SensitiveVec<u8>, i32> {
        let query = unsafe {
            item(&[
                (kSecReturnData, kCFBooleanTrue),
                (kSecMatchLimit, kSecMatchLimitOne),
            ])?
        };
        let mut result: CFTypeRef = ptr::null();
        check(unsafe { SecItemCopyMatching(query.0, &mut result) })?;
        let data = Owned::new(result)?;
        let released = unsafe {
            std::slice::from_raw_parts_mut(
                CFDataGetBytePtr(data.0) as *mut u8,
                CFDataGetLength(data.0) as usize,
            )
        };
        let phrase = SensitiveVec(released.to_vec());
        wipe(released);
        Ok(phrase)
    }

    pub(crate) fn delete() -> Result<(), i32> {
        match unsafe { SecItemDelete(item(&[])?.0) } {
            SUCCESS | ITEM_NOT_FOUND => Ok(()),
            status => Err(status),
        }
    }
}
