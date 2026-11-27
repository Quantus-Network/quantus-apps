//! What iOS and Android answer when asked whether they can authenticate the
//! owner the way a policy needs, read the way [`available`](super::available)
//! needs it. Kept apart from the backends so the host tests cover it.
//!
//! A biometric counts as absent only where the device says it has no sensor
//! or nothing enrolled. Any other answer is refused, so the passcode never
//! stands in for a biometric the device only cannot use now.

use super::{refusal, Failure, Refusal, SealPolicy};

fn unknown(policy: SealPolicy, answer: String) -> Refusal {
    refusal(
        Failure::Unavailable,
        format!("The device cannot say whether it enforces {policy:?} now: {answer}"),
    )
}

/// `canEvaluatePolicy` for `policy` answered `able`, with the `LAError` code
/// `error` (zero for none), on a device whose `biometryType` is `biometry`.
#[cfg(any(test, target_os = "ios"))]
pub(super) fn local_authentication(
    policy: SealPolicy,
    able: bool,
    error: isize,
    biometry: isize,
) -> Result<bool, Refusal> {
    /// `LAErrorPasscodeNotSet`
    const PASSCODE_NOT_SET: isize = -5;
    /// `LAErrorBiometryNotAvailable`: no sensor, or one this app may not use
    /// now, which includes Face ID turned off for it.
    const BIOMETRY_NOT_AVAILABLE: isize = -6;
    /// `LAErrorBiometryNotEnrolled`
    const BIOMETRY_NOT_ENROLLED: isize = -7;
    /// `LAErrorBiometryLockout`: enrolled, but locked until the passcode is
    /// entered. The keychain accepts the item, and the next read says so.
    const BIOMETRY_LOCKOUT: isize = -8;
    /// `LABiometryTypeNone`: no biometric sensor.
    const NO_SENSOR: isize = 0;
    match (policy, error) {
        _ if able => Ok(true),
        (_, PASSCODE_NOT_SET) | (SealPolicy::Biometry, BIOMETRY_NOT_ENROLLED) => Ok(false),
        (SealPolicy::Biometry, BIOMETRY_NOT_AVAILABLE) if biometry == NO_SENSOR => Ok(false),
        (SealPolicy::Biometry, BIOMETRY_LOCKOUT) => Ok(true),
        _ => Err(unknown(
            policy,
            format!("LAError {error}, biometry type {biometry}"),
        )),
    }
}

/// `BiometricManager.canAuthenticate` answered `status` for `policy`.
#[cfg(any(test, target_os = "android"))]
pub(super) fn biometric_manager(policy: SealPolicy, status: i8) -> Result<bool, Refusal> {
    /// `BIOMETRIC_SUCCESS`
    const SUCCESS: i8 = 0;
    /// `BIOMETRIC_ERROR_NONE_ENROLLED`: no biometric enrolled, or for the
    /// screen lock, none set.
    const NONE_ENROLLED: i8 = 11;
    /// `BIOMETRIC_ERROR_NO_HARDWARE`: no sensor of the strong class.
    const NO_HARDWARE: i8 = 12;
    /// `BIOMETRIC_ERROR_UNSUPPORTED`: what `SealedSecretStore` answers for the
    /// screen lock before Android 11, where the Keystore authorises a single
    /// use of a key by a biometric only.
    const UNSUPPORTED: i8 = -2;
    match (policy, status) {
        (_, SUCCESS) => Ok(true),
        (_, NONE_ENROLLED | NO_HARDWARE) | (SealPolicy::DevicePasscode, UNSUPPORTED) => Ok(false),
        _ => Err(unknown(policy, format!("BiometricManager status {status}"))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use SealPolicy::{Biometry, DevicePasscode};

    const FACE_ID: isize = 2;
    const NO_SENSOR: isize = 0;

    fn refused(answer: Result<bool, Refusal>) -> bool {
        matches!(
            answer,
            Err(Refusal {
                failure: Failure::Unavailable,
                ..
            })
        )
    }

    #[test]
    fn ios_counts_a_biometric_absent_only_without_a_sensor_or_an_enrolment() {
        assert!(local_authentication(Biometry, true, 0, FACE_ID).unwrap());
        assert!(local_authentication(Biometry, false, -8, FACE_ID).unwrap());
        assert!(!local_authentication(Biometry, false, -7, FACE_ID).unwrap());
        assert!(!local_authentication(Biometry, false, -6, NO_SENSOR).unwrap());
        assert!(!local_authentication(Biometry, false, -5, FACE_ID).unwrap());

        assert!(refused(local_authentication(Biometry, false, -6, FACE_ID)));
        assert!(refused(local_authentication(Biometry, false, -1, FACE_ID)));
        assert!(refused(local_authentication(Biometry, false, 0, FACE_ID)));
    }

    #[test]
    fn ios_counts_the_passcode_absent_only_when_it_is_not_set() {
        assert!(local_authentication(DevicePasscode, true, 0, FACE_ID).unwrap());
        assert!(!local_authentication(DevicePasscode, false, -5, NO_SENSOR).unwrap());

        assert!(refused(local_authentication(
            DevicePasscode,
            false,
            -7,
            FACE_ID
        )));
        assert!(refused(local_authentication(
            DevicePasscode,
            false,
            -10,
            FACE_ID
        )));
    }

    #[test]
    fn android_counts_a_biometric_absent_only_without_a_sensor_or_an_enrolment() {
        assert!(biometric_manager(Biometry, 0).unwrap());
        assert!(!biometric_manager(Biometry, 11).unwrap());
        assert!(!biometric_manager(Biometry, 12).unwrap());

        for status in [1, 15, -1, -2] {
            assert!(
                refused(biometric_manager(Biometry, status)),
                "status {status}"
            );
        }
    }

    #[test]
    fn android_counts_the_screen_lock_absent_when_unset_or_too_old_to_use() {
        assert!(biometric_manager(DevicePasscode, 0).unwrap());
        assert!(!biometric_manager(DevicePasscode, 11).unwrap());
        assert!(!biometric_manager(DevicePasscode, -2).unwrap());

        for status in [1, 15, -1] {
            assert!(
                refused(biometric_manager(DevicePasscode, status)),
                "status {status}"
            );
        }
    }
}
