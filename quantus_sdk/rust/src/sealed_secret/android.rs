//! The Android Keystore as the sealed store, through `SealedSecretStore.java`:
//! the secret is encrypted under a key that only decrypts inside the Keystore,
//! for one operation, after the system prompt has authenticated the user.
//!
//! The Java half attaches itself once. Every call then crosses on the calling
//! thread and blocks there while the prompt is up, so the secret goes from
//! the Keystore to Rust without passing through Dart. Both byte arrays that
//! carried it across are zeroed before they are let go.

use super::{refusal, Failure, Refusal, SealPolicy};
use crate::sensitive::SensitiveVec;
use jni_sys::{
    jbyteArray, jint, jobject, jvalue, JNIEnv, JavaVM, JNI_EDETACHED, JNI_OK, JNI_VERSION_1_6,
};
use std::ffi::{c_void, CStr, CString};
use std::ptr;
use std::sync::OnceLock;

const AVAILABLE: jint = 0;
const STORED: jint = 1;
const STORE: jint = 2;
const READ: jint = 3;
const DELETE: jint = 4;

const POLICIES: [SealPolicy; 2] = [SealPolicy::Biometry, SealPolicy::DevicePasscode];

impl SealPolicy {
    /// What `SealedSecretStore.java` calls this policy; zero is none.
    fn code(self) -> jint {
        match self {
            SealPolicy::Biometry => 1,
            SealPolicy::DevicePasscode => 2,
        }
    }
}

/// The failure behind each non-zero status byte of a reply, from one up.
const FAILURES: [Failure; 5] = [
    Failure::Cancelled,
    Failure::NotRecognised,
    Failure::Missing,
    Failure::Unavailable,
    Failure::Platform,
];

struct Attached {
    vm: *mut JavaVM,
    store: jobject,
}

/// A VM pointer and a global reference are both valid on every thread.
unsafe impl Send for Attached {}
unsafe impl Sync for Attached {}

static ATTACHED: OnceLock<Attached> = OnceLock::new();

fn platform(detail: impl ToString) -> Refusal {
    refusal(Failure::Platform, detail)
}

/// `SealedSecretStore.attach()`: keeps the store for the calls below.
///
/// # Safety
/// Called by the Java VM with its own environment and the store instance.
#[no_mangle]
pub unsafe extern "system" fn Java_com_quantus_sealedsecret_SealedSecretStore_attach(
    env: *mut JNIEnv,
    store: jobject,
) {
    let jni = &**env;
    let mut vm = ptr::null_mut();
    if (jni.GetJavaVM.unwrap())(env, &mut vm) != JNI_OK {
        return;
    }
    ATTACHED.get_or_init(|| Attached {
        vm,
        store: (jni.NewGlobalRef.unwrap())(env, store),
    });
}

/// One call of `byte[] call(int, String, int, String, byte[])`. The reply is
/// a status byte, zero for success, and then the payload.
fn call(
    operation: jint,
    slot: &str,
    policy: jint,
    prompt: &str,
    secret: &[u8],
) -> Result<SensitiveVec<u8>, Refusal> {
    let attached = ATTACHED
        .get()
        .ok_or_else(|| platform("SealedSecretStore was not bound to an activity"))?;
    let slot = CString::new(slot).map_err(platform)?;
    let prompt = CString::new(prompt).map_err(platform)?;
    let reply = unsafe {
        let vm = &**attached.vm;
        let mut env: *mut JNIEnv = ptr::null_mut();
        let slot_for_env = &mut env as *mut *mut JNIEnv as *mut *mut c_void;
        let joined_here =
            (vm.GetEnv.unwrap())(attached.vm, slot_for_env, JNI_VERSION_1_6) == JNI_EDETACHED;
        if joined_here
            && (vm.AttachCurrentThread.unwrap())(attached.vm, slot_for_env, ptr::null_mut())
                != JNI_OK
        {
            return Err(platform("This thread could not join the Java VM"));
        }
        let reply = exchange(
            env,
            attached.store,
            operation,
            &slot,
            policy,
            &prompt,
            secret,
        );
        if joined_here {
            (vm.DetachCurrentThread.unwrap())(attached.vm);
        }
        reply
    }?;
    match reply.first() {
        Some(0) => Ok(SensitiveVec(reply[1..].to_vec())),
        Some(&status) => Err(refusal(
            *FAILURES
                .get(status as usize - 1)
                .ok_or_else(|| platform(format!("Unknown status {status}")))?,
            String::from_utf8_lossy(&reply[1..]),
        )),
        None => Err(platform("SealedSecretStore answered nothing")),
    }
}

unsafe fn exchange(
    env: *mut JNIEnv,
    store: jobject,
    operation: jint,
    slot: &CStr,
    policy: jint,
    prompt: &CStr,
    secret: &[u8],
) -> Result<SensitiveVec<u8>, Refusal> {
    let jni = &**env;
    let class = (jni.GetObjectClass.unwrap())(env, store);
    let method = (jni.GetMethodID.unwrap())(
        env,
        class,
        c"call".as_ptr(),
        c"(ILjava/lang/String;ILjava/lang/String;[B)[B".as_ptr(),
    );
    if method.is_null() {
        (jni.ExceptionClear.unwrap())(env);
        return Err(platform("SealedSecretStore.call is missing"));
    }
    let java_slot = (jni.NewStringUTF.unwrap())(env, slot.as_ptr());
    let java_prompt = (jni.NewStringUTF.unwrap())(env, prompt.as_ptr());
    let java_secret: jbyteArray = (jni.NewByteArray.unwrap())(env, secret.len() as jint);
    (jni.SetByteArrayRegion.unwrap())(
        env,
        java_secret,
        0,
        secret.len() as jint,
        secret.as_ptr().cast(),
    );
    let arguments = [
        jvalue { i: operation },
        jvalue { l: java_slot },
        jvalue { i: policy },
        jvalue { l: java_prompt },
        jvalue { l: java_secret },
    ];
    let java_reply: jbyteArray =
        (jni.CallObjectMethodA.unwrap())(env, store, method, arguments.as_ptr());
    let threw = (jni.ExceptionCheck.unwrap())(env) != 0;
    if threw {
        (jni.ExceptionDescribe.unwrap())(env);
        (jni.ExceptionClear.unwrap())(env);
    }
    let reply = if threw || java_reply.is_null() {
        Err(platform("SealedSecretStore.call threw"))
    } else {
        let length = (jni.GetArrayLength.unwrap())(env, java_reply);
        let mut reply = SensitiveVec(vec![0u8; length as usize]);
        (jni.GetByteArrayRegion.unwrap())(env, java_reply, 0, length, reply.0.as_mut_ptr().cast());
        blank(env, java_reply, length);
        Ok(reply)
    };
    blank(env, java_secret, secret.len() as jint);
    for local in [class, java_slot, java_prompt, java_secret, java_reply] {
        if !local.is_null() {
            (jni.DeleteLocalRef.unwrap())(env, local);
        }
    }
    reply
}

unsafe fn blank(env: *mut JNIEnv, array: jbyteArray, length: jint) {
    let zeros = vec![0i8; length as usize];
    ((**env).SetByteArrayRegion.unwrap())(env, array, 0, length, zeros.as_ptr());
}

fn policy_in(reply: &[u8]) -> Result<Option<SealPolicy>, Refusal> {
    match reply {
        [0] => Ok(None),
        [code] => POLICIES
            .into_iter()
            .find(|policy| policy.code() == jint::from(*code))
            .map(Some)
            .ok_or_else(|| platform(format!("Unknown policy {code}"))),
        _ => Err(platform("SealedSecretStore answered no policy")),
    }
}

pub(crate) fn available() -> Result<Option<SealPolicy>, Refusal> {
    policy_in(&call(AVAILABLE, "", 0, "", &[])?)
}

pub(crate) fn stored(slot: &str) -> Result<Option<SealPolicy>, Refusal> {
    policy_in(&call(STORED, slot, 0, "", &[])?)
}

pub(crate) fn store(slot: &str, secret: &[u8], policy: SealPolicy) -> Result<(), Refusal> {
    call(STORE, slot, policy.code(), "", secret).map(drop)
}

pub(crate) fn read(slot: &str, prompt: &str) -> Result<SensitiveVec<u8>, Refusal> {
    call(READ, slot, 0, prompt, &[])
}

pub(crate) fn delete(slot: &str) -> Result<(), Refusal> {
    call(DELETE, slot, 0, "", &[]).map(drop)
}
