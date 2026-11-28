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
//!
//! A slot keeps its secret in one backend item per policy, named after both.
//! Only [`reseal`] puts a second item beside the first, and deleting the old
//! one is its commit. Two items are a move whose process ended before that
//! commit, and the next call into the slot deletes the copy under the
//! stronger policy. Calls into slots run one at a time, so none of them sees
//! a move halfway.

use crate::sensitive::SensitiveVec;
use std::sync::{Mutex, MutexGuard, PoisonError};

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
#[cfg(any(test, target_os = "ios", target_os = "android"))]
mod enrolment;

/// Strongest first.
const POLICIES: [SealPolicy; 2] = [SealPolicy::Biometry, SealPolicy::DevicePasscode];

static ONE_AT_A_TIME: Mutex<()> = Mutex::new(());

/// The lock guards no data, so a panic under it leaves nothing to repair.
fn one_at_a_time() -> MutexGuard<'static, ()> {
    ONE_AT_A_TIME.lock().unwrap_or_else(PoisonError::into_inner)
}

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

impl SealPolicy {
    /// How the backends name this policy.
    fn name(self) -> &'static str {
        match self {
            SealPolicy::Biometry => "biometry",
            SealPolicy::DevicePasscode => "passcode",
        }
    }
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

/// The strongest policy this device can enforce now, or `None` without a
/// screen lock. Never prompts.
pub(crate) fn available() -> Result<Option<SealPolicy>, Refusal> {
    for policy in POLICIES {
        if backend::enforces(policy)? {
            return Ok(Some(policy));
        }
    }
    Ok(None)
}

/// The policy the secret in a slot is sealed under, or `None` for an empty
/// slot. Never prompts.
pub(crate) fn stored(slot: &str) -> Result<Option<SealPolicy>, Refusal> {
    let _turn = one_at_a_time();
    settle(slot)
}

/// Seals a secret the caller holds in a slot, replacing what was there. Never
/// prompts, and refuses a policy the device cannot enforce now. What it
/// replaces goes first, so only [`reseal`] may replace a secret that exists
/// nowhere else.
pub(crate) fn store(slot: &str, secret: &[u8], policy: SealPolicy) -> Result<(), Refusal> {
    let _turn = one_at_a_time();
    enforced(policy)?;
    remove(slot)?;
    backend::store(&item(slot, policy), secret, policy)
}

/// Takes the secret out of a slot for one use. Blocks on the system prompt,
/// which shows the caller's text where the system has room for one.
pub(crate) fn read(slot: &str, prompt: &str) -> Result<SensitiveVec<u8>, Refusal> {
    let _turn = one_at_a_time();
    let policy = settle(slot)?.ok_or_else(empty)?;
    backend::read(&item(slot, policy), prompt)
}

/// Removes the secret in a slot. Never prompts; an empty slot is not an error.
pub(crate) fn delete(slot: &str) -> Result<(), Refusal> {
    let _turn = one_at_a_time();
    remove(slot)
}

/// Moves the secret in `slot` under a stronger `policy`: one prompt releases
/// it as it is sealed now, a second proves the device releases the copy
/// sealed beside it under `policy`. Only then is the old item deleted, and
/// until it is the old seal stands.
pub(crate) fn reseal(slot: &str, policy: SealPolicy, prompt: &str) -> Result<(), Refusal> {
    let _turn = one_at_a_time();
    let sealed_under = settle(slot)?.ok_or_else(empty)?;
    if !stronger(policy, sealed_under) {
        return Err(refusal(
            Failure::Platform,
            format!("{policy:?} is not stronger than {sealed_under:?}"),
        ));
    }
    enforced(policy)?;
    let secret = backend::read(&item(slot, sealed_under), prompt)?;
    let staged = item(slot, policy);
    let proven = backend::store(&staged, &secret, policy)
        .and_then(|()| backend::read(&staged, prompt))
        .and_then(|released| same(&released, &secret));
    match proven {
        Ok(()) => backend::delete(&item(slot, sealed_under)),
        Err(refused) => {
            backend::delete(&staged)?;
            Err(refused)
        }
    }
}

/// The backend item that holds the secret of `slot` under `policy`.
fn item(slot: &str, policy: SealPolicy) -> String {
    format!("{slot}_{}", policy.name())
}

fn empty() -> Refusal {
    refusal(Failure::Missing, "Nothing is sealed in this slot")
}

fn stronger(policy: SealPolicy, than: SealPolicy) -> bool {
    let rank = |policy| POLICIES.iter().position(|&listed| listed == policy);
    rank(policy) < rank(than)
}

fn enforced(policy: SealPolicy) -> Result<(), Refusal> {
    if backend::enforces(policy)? {
        Ok(())
    } else {
        Err(refusal(
            Failure::Unavailable,
            format!("This device cannot enforce {policy:?} now"),
        ))
    }
}

/// The policy of the secret in `slot`. A move only goes to a stronger policy,
/// so of two items the weaker is the committed one, and the stronger a copy
/// that may never have been proven: it is deleted.
fn settle(slot: &str) -> Result<Option<SealPolicy>, Refusal> {
    let mut committed = None;
    for policy in POLICIES {
        if backend::stored(&item(slot, policy))?.is_none() {
            continue;
        }
        if let Some(unproven) = committed.replace(policy) {
            eprintln!("[sealed_secret] {slot}: deleting the {unproven:?} copy of a move that never committed");
            backend::delete(&item(slot, unproven))?;
        }
    }
    Ok(committed)
}

/// Strongest first, so that a removal cut short never leaves an unproven copy
/// alone in the slot.
fn remove(slot: &str) -> Result<(), Refusal> {
    POLICIES
        .into_iter()
        .try_for_each(|policy| backend::delete(&item(slot, policy)))
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
    use super::backend::{self, device};
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
    fn keeps_the_old_seal_when_the_new_policy_is_not_proven() {
        seal_under_passcode();
        device(|d| d.refusals = vec![Failure::NotRecognised]);
        device(|d| d.prompts_before_refusal = 1);

        let error = reseal(SLOT, SealPolicy::Biometry, "prompt").unwrap_err();

        assert_eq!(error.failure, Failure::NotRecognised);
        assert_eq!(stored(SLOT).unwrap(), Some(SealPolicy::DevicePasscode));
        assert_eq!(&read(SLOT, "prompt").unwrap()[..], b"secret");
        assert_eq!(staged_copy(), None);
    }

    fn staged_copy() -> Option<SealPolicy> {
        backend::stored(&item(SLOT, SealPolicy::Biometry)).unwrap()
    }

    #[test]
    fn never_loses_the_secret_to_a_move_whose_process_ends() {
        for writes in 0.. {
            seal_under_passcode();
            device(|d| d.writes_before_crash = Some(writes));
            let moved = reseal(SLOT, SealPolicy::Biometry, "prompt");
            device(|d| {
                d.crashed = false;
                d.writes_before_crash = None;
            });

            let policy = stored(SLOT).unwrap();
            assert_eq!(&read(SLOT, "prompt").unwrap()[..], b"secret");
            if moved.is_ok() {
                assert_eq!(policy, Some(SealPolicy::Biometry));
                assert_eq!(writes, 2);
                break;
            }
            assert_eq!(moved.unwrap_err().failure, Failure::Platform);
            assert_eq!(policy, Some(SealPolicy::DevicePasscode));
            assert_eq!(staged_copy(), None);
        }
    }

    #[test]
    fn moves_only_to_a_stronger_policy() {
        device(|d| d.enrolled = Some(SealPolicy::Biometry));
        store(SLOT, b"secret", SealPolicy::Biometry).unwrap();
        for policy in [SealPolicy::Biometry, SealPolicy::DevicePasscode] {
            let error = reseal(SLOT, policy, "prompt").unwrap_err();
            assert_eq!(error.failure, Failure::Platform);
        }
        assert_eq!(device(|d| d.prompts), 0);
        assert_eq!(stored(SLOT).unwrap(), Some(SealPolicy::Biometry));
    }

    #[test]
    fn has_nothing_to_reseal_in_an_empty_slot() {
        device(|d| d.enrolled = Some(SealPolicy::Biometry));
        let error = reseal(SLOT, SealPolicy::Biometry, "prompt").unwrap_err();
        assert_eq!(error.failure, Failure::Missing);
    }
}
