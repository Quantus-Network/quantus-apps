//! A secret the device releases for one use at a time, after authenticating
//! its owner under a [`SealPolicy`].
//!
//! The operating system enforces the policy, not this process: the iOS
//! keychain or the Android Keystore holds the secret and prompts on every
//! [`read`]. Nothing here keeps a released secret or an authentication, so
//! every read is its own prompt. The secret never syncs and never leaves the
//! device, and the operating system destroys it when what its policy rests on
//! changes: the enrolled biometrics, or the screen lock itself.
//!
//! [`available`] is the scheme: a biometric where one is enrolled, the device
//! passcode only where none is, and nothing without a screen lock.

use crate::sensitive::SensitiveVec;

#[cfg(target_os = "ios")]
#[path = "ios.rs"]
mod backend;
#[cfg(target_os = "android")]
#[path = "android.rs"]
mod backend;
#[cfg(all(test, not(any(target_os = "ios", target_os = "android"))))]
#[path = "memory.rs"]
pub(crate) mod backend;
#[cfg(not(any(test, target_os = "ios", target_os = "android")))]
#[path = "unsupported.rs"]
mod backend;

/// The strongest policy this device can enforce now, or `None` without a
/// screen lock. Never prompts.
pub(crate) use backend::available;
/// Removes the secret in a slot. Never prompts; an empty slot is not an error.
pub(crate) use backend::delete;
/// Takes the secret out of a slot for one use. Blocks on the system prompt,
/// which shows the caller's text where the system has room for one.
pub(crate) use backend::read;
/// Seals a secret in a slot, replacing what was there. Never prompts, and
/// refuses a policy the device cannot enforce now.
pub(crate) use backend::store;
/// The policy the secret in a slot is sealed under, or `None` for an empty
/// slot. Never prompts.
pub(crate) use backend::stored;

/// What the device demands before each release of a sealed secret.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SealPolicy {
    /// A match against the biometrics enrolled when the secret was sealed,
    /// with no passcode in its place. Enrolling another destroys the secret.
    Biometry,
    /// The passcode, PIN or pattern of the device, for one with no biometric
    /// enrolled. Removing the screen lock destroys the secret.
    DevicePasscode,
}

/// A platform with no sealed store raises only `Missing` and `Platform`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[cfg_attr(
    not(any(test, target_os = "ios", target_os = "android")),
    allow(dead_code)
)]
pub(crate) enum Failure {
    /// The prompt was dismissed.
    Cancelled,
    /// No match, or the device has locked its biometrics.
    NotRecognised,
    /// The slot is empty: never sealed, or destroyed by the operating system.
    Missing,
    /// The device cannot enforce the policy asked for, or cannot prompt now.
    Unavailable,
    /// The platform refused for a reason of its own, named in the detail.
    Platform,
}

#[derive(Debug)]
pub(crate) struct Refusal {
    pub(crate) failure: Failure,
    pub(crate) detail: String,
}

pub(crate) fn refusal(failure: Failure, detail: impl ToString) -> Refusal {
    Refusal {
        failure,
        detail: detail.to_string(),
    }
}

/// Moves the secret in `slot` under `policy`: one prompt releases it as it is
/// sealed now, a second proves the device releases it under the new policy.
/// If sealing or that proof fails the secret goes back under the policy it had.
pub(crate) fn reseal(slot: &str, policy: SealPolicy, prompt: &str) -> Result<(), Refusal> {
    let sealed_under =
        stored(slot)?.ok_or_else(|| refusal(Failure::Missing, "Nothing is sealed in this slot"))?;
    let secret = read(slot, prompt)?;
    let moved = store(slot, &secret, policy)
        .and_then(|()| read(slot, prompt))
        .and_then(|released| same(&released, &secret));
    if moved.is_err() {
        store(slot, &secret, sealed_under)?;
    }
    moved
}

fn same(released: &SensitiveVec<u8>, secret: &SensitiveVec<u8>) -> Result<(), Refusal> {
    if released[..] != secret[..] {
        return Err(refusal(
            Failure::Platform,
            "The device released another secret than the one sealed",
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::backend::device;
    use super::*;

    const SLOT: &str = "slot";

    fn seal_under_passcode() {
        device(|d| d.enrolled = Some(SealPolicy::DevicePasscode));
        store(SLOT, b"secret", SealPolicy::DevicePasscode).unwrap();
        device(|d| d.enrolled = Some(SealPolicy::Biometry));
    }

    #[test]
    fn offers_the_strongest_policy_the_device_enforces() {
        assert_eq!(available().unwrap(), None);
        device(|d| d.enrolled = Some(SealPolicy::DevicePasscode));
        assert_eq!(available().unwrap(), Some(SealPolicy::DevicePasscode));
        device(|d| d.enrolled = Some(SealPolicy::Biometry));
        assert_eq!(available().unwrap(), Some(SealPolicy::Biometry));
    }

    #[test]
    fn refuses_a_policy_the_device_cannot_enforce() {
        let error = store(SLOT, b"secret", SealPolicy::DevicePasscode).unwrap_err();
        assert_eq!(error.failure, Failure::Unavailable);

        device(|d| d.enrolled = Some(SealPolicy::DevicePasscode));
        let error = store(SLOT, b"secret", SealPolicy::Biometry).unwrap_err();
        assert_eq!(error.failure, Failure::Unavailable);
        assert_eq!(stored(SLOT).unwrap(), None);
    }

    #[test]
    fn prompts_for_every_read_and_for_nothing_else() {
        device(|d| d.enrolled = Some(SealPolicy::Biometry));
        store(SLOT, b"secret", SealPolicy::Biometry).unwrap();
        assert_eq!(stored(SLOT).unwrap(), Some(SealPolicy::Biometry));
        assert_eq!(device(|d| d.prompts), 0);

        assert_eq!(&read(SLOT, "prompt").unwrap()[..], b"secret");
        assert_eq!(&read(SLOT, "prompt").unwrap()[..], b"secret");
        assert_eq!(device(|d| d.prompts), 2);

        delete(SLOT).unwrap();
        delete(SLOT).unwrap();
        assert_eq!(
            read(SLOT, "prompt").err().unwrap().failure,
            Failure::Missing
        );
    }

    #[test]
    fn reseals_under_a_stronger_policy_with_two_prompts() {
        seal_under_passcode();

        reseal(SLOT, SealPolicy::Biometry, "prompt").unwrap();

        assert_eq!(stored(SLOT).unwrap(), Some(SealPolicy::Biometry));
        assert_eq!(device(|d| d.prompts), 2);
        assert_eq!(&read(SLOT, "prompt").unwrap()[..], b"secret");
    }

    #[test]
    fn keeps_the_old_policy_when_the_first_prompt_is_dismissed() {
        seal_under_passcode();
        device(|d| d.refusals = vec![Failure::Cancelled]);

        let error = reseal(SLOT, SealPolicy::Biometry, "prompt").unwrap_err();

        assert_eq!(error.failure, Failure::Cancelled);
        assert_eq!(stored(SLOT).unwrap(), Some(SealPolicy::DevicePasscode));
    }

    #[test]
    fn puts_the_secret_back_when_the_new_policy_is_not_proven() {
        seal_under_passcode();
        device(|d| d.refusals = vec![Failure::NotRecognised]);
        device(|d| d.prompts_before_refusal = 1);

        let error = reseal(SLOT, SealPolicy::Biometry, "prompt").unwrap_err();

        assert_eq!(error.failure, Failure::NotRecognised);
        assert_eq!(stored(SLOT).unwrap(), Some(SealPolicy::DevicePasscode));
        assert_eq!(&read(SLOT, "prompt").unwrap()[..], b"secret");
    }

    #[test]
    fn has_nothing_to_reseal_in_an_empty_slot() {
        device(|d| d.enrolled = Some(SealPolicy::Biometry));
        let error = reseal(SLOT, SealPolicy::Biometry, "prompt").unwrap_err();
        assert_eq!(error.failure, Failure::Missing);
    }
}
