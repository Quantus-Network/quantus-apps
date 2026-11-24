//! The cold wallet's signing key, used without handing key material to Dart.
//!
//! The recovery phrase is a sealed secret ([`crate::sealed_secret`]): the
//! device releases it for one operation after authenticating its owner. Each
//! `sealed_*` call takes it out behind one prompt and wipes it before
//! returning, so only public keys and signatures cross the bridge. None of
//! them is `sync`, because the prompt blocks and must not hold the UI thread.

use crate::api::crypto::{address_of, dispatch, DilithiumScheme};
use crate::api::near::{sign_declared_transaction, ML_DSA_65_ONLY};
use crate::sealed_secret::{self, Failure, Refusal, SealPolicy};
use crate::sensitive::SensitiveVec;
use crate::signing_context;
use qp_rusty_crystals_hdwallet::{mnemonic_to_seed, SensitiveBytes32, SensitiveBytes64};

/// The slot of the sealed store that holds the recovery phrase.
const PHRASE_SLOT: &str = "cold_wallet_recovery_phrase";

/// Where an account's key sits under the phrase.
pub struct AccountPath {
    pub path: String,
    pub scheme: DilithiumScheme,
}

/// The public half of an account's key.
#[derive(Debug)]
pub struct AccountPublicKey {
    pub address: String,
    pub public_key: Vec<u8>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SealedKeyFailure {
    /// The prompt was dismissed.
    Cancelled,
    /// No match, or the device has locked its biometrics.
    NotRecognised,
    /// No sealed phrase on this device: never stored, or destroyed by the
    /// operating system when the screen lock or the biometrics changed.
    Missing,
    /// The device cannot enforce the policy asked for, or cannot prompt now.
    Unavailable,
    /// The path derives another account than the one the caller named.
    WrongAccount,
    /// The phrase, path or request cannot be used.
    Invalid,
    /// The platform refused for a reason of its own, named in the detail.
    Platform,
}

#[derive(Debug)]
pub struct SealedKeyError {
    pub failure: SealedKeyFailure,
    pub detail: String,
}

fn failed(failure: SealedKeyFailure, detail: impl ToString) -> SealedKeyError {
    SealedKeyError {
        failure,
        detail: detail.to_string(),
    }
}

fn invalid(detail: impl ToString) -> SealedKeyError {
    failed(SealedKeyFailure::Invalid, detail)
}

fn refused(refusal: Refusal) -> SealedKeyError {
    let failure = match refusal.failure {
        Failure::Cancelled => SealedKeyFailure::Cancelled,
        Failure::NotRecognised => SealedKeyFailure::NotRecognised,
        Failure::Missing => SealedKeyFailure::Missing,
        Failure::Unavailable => SealedKeyFailure::Unavailable,
        Failure::Platform => SealedKeyFailure::Platform,
    };
    failed(failure, refusal.detail)
}

/// Stretches `phrase` into `seed`. The phrase is wiped on every path.
fn stretch(phrase: String, seed: &mut SensitiveBytes64) -> Result<(), SealedKeyError> {
    mnemonic_to_seed(phrase, None, seed).map_err(invalid)
}

/// Takes the sealed phrase out for one operation. Prompts.
fn sealed_text(prompt: &str) -> Result<String, SealedKeyError> {
    let mut phrase = sealed_secret::read(PHRASE_SLOT, prompt).map_err(refused)?;
    String::from_utf8(std::mem::take(&mut phrase.0)).map_err(|error| {
        drop(SensitiveVec(error.into_bytes()));
        invalid("The sealed phrase is not text")
    })
}

fn sealed_seed(prompt: &str, seed: &mut SensitiveBytes64) -> Result<(), SealedKeyError> {
    stretch(sealed_text(prompt)?, seed)
}

fn public_key_at(
    seed: &SensitiveBytes64,
    account: &AccountPath,
) -> Result<AccountPublicKey, SealedKeyError> {
    dispatch!(account.scheme, dsa, hd, {
        let keypair = hd::derive_key_from_seed(seed, &account.path).map_err(invalid)?;
        let public_key = keypair.public().to_bytes().to_vec();
        Ok(AccountPublicKey {
            address: address_of(&public_key),
            public_key,
        })
    })
}

fn public_keys(
    seed: &SensitiveBytes64,
    accounts: &[AccountPath],
) -> Result<Vec<AccountPublicKey>, SealedKeyError> {
    accounts
        .iter()
        .map(|account| public_key_at(seed, account))
        .collect()
}

/// Refuses a key that is not the account the reviewed request named, so a
/// tampered account list cannot make one key sign under another's label.
fn require_account(public_key: &[u8], address: &str) -> Result<(), SealedKeyError> {
    let derived = address_of(public_key);
    if derived != address {
        return Err(failed(
            SealedKeyFailure::WrongAccount,
            format!("This path derives {derived}, not {address}"),
        ));
    }
    Ok(())
}

fn sign_extrinsic_at(
    seed: &SensitiveBytes64,
    account: &AccountPath,
    address: &str,
    message: &[u8],
    spec_version: u32,
    entropy: Option<[u8; 32]>,
) -> Result<Vec<u8>, SealedKeyError> {
    let mut entropy = entropy;
    let hedge = entropy.as_mut().map(SensitiveBytes32::new);
    let context = signing_context::context_for_spec(spec_version);
    dispatch!(account.scheme, dsa, hd, {
        let keypair = hd::derive_key_from_seed(seed, &account.path).map_err(invalid)?;
        let public_key = keypair.public().to_bytes();
        require_account(&public_key, address)?;
        let signature = keypair
            .sign(message, context, hedge.as_ref())
            .map_err(|error| invalid(format!("Signing failed: {error:?}")))?;
        Ok([signature.as_slice(), public_key.as_slice()].concat())
    })
}

fn sign_near_at(
    seed: &SensitiveBytes64,
    account: &AccountPath,
    address: &str,
    transaction: &[u8],
    entropy: Option<[u8; 32]>,
) -> Result<Vec<u8>, SealedKeyError> {
    if account.scheme != DilithiumScheme::MlDsa65 {
        return Err(invalid(ML_DSA_65_ONLY));
    }
    let keypair = qp_rusty_crystals_hdwallet::ml_dsa_65::derive_key_from_seed(seed, &account.path)
        .map_err(invalid)?;
    let public_key = keypair.public().to_bytes();
    require_account(&public_key, address)?;
    sign_declared_transaction(keypair.secret(), &public_key, transaction, entropy).map_err(invalid)
}

/// Public keys from a phrase the caller still holds: at creation, import and
/// restore, before it is sealed. Never touches the sealed phrase.
pub fn derive_account_keys(
    phrase: String,
    accounts: Vec<AccountPath>,
) -> Result<Vec<AccountPublicKey>, SealedKeyError> {
    let mut seed = SensitiveBytes64::zeroed();
    stretch(phrase, &mut seed)?;
    public_keys(&seed, &accounts)
}

/// The strongest policy this device can seal under now: a biometric where
/// one is enrolled, the device passcode where none is, `None` without a
/// screen lock. Never prompts.
pub fn seal_policy_available() -> Result<Option<SealPolicy>, SealedKeyError> {
    sealed_secret::available().map_err(refused)
}

/// The policy the phrase on this device is sealed under, or `None` when there
/// is no sealed phrase. Never prompts.
pub fn sealed_phrase_policy() -> Result<Option<SealPolicy>, SealedKeyError> {
    sealed_secret::stored(PHRASE_SLOT).map_err(refused)
}

/// Seals `phrase` under `policy`, replacing any phrase already sealed. Never
/// prompts.
pub fn seal_phrase(phrase: String, policy: SealPolicy) -> Result<(), SealedKeyError> {
    let phrase = SensitiveVec(phrase.into_bytes());
    sealed_secret::store(PHRASE_SLOT, &phrase, policy).map_err(refused)
}

/// Moves the sealed phrase under `policy`. Two prompts: one under the policy
/// it has, one under the new; it keeps the policy it has unless both pass.
pub fn reseal_phrase(policy: SealPolicy, prompt: String) -> Result<(), SealedKeyError> {
    sealed_secret::reseal(PHRASE_SLOT, policy, &prompt).map_err(refused)
}

/// Public keys of `accounts` under the sealed phrase. One prompt for the batch.
pub fn sealed_account_keys(
    accounts: Vec<AccountPath>,
    prompt: String,
) -> Result<Vec<AccountPublicKey>, SealedKeyError> {
    let mut seed = SensitiveBytes64::zeroed();
    sealed_seed(&prompt, &mut seed)?;
    public_keys(&seed, &accounts)
}

/// `signature ‖ public_key` over a Quantus extrinsic payload, by the account
/// at `account`, refused unless that account is `address`. One prompt.
pub fn sealed_sign_extrinsic(
    account: AccountPath,
    address: String,
    message: Vec<u8>,
    spec_version: u32,
    entropy: Option<[u8; 32]>,
    prompt: String,
) -> Result<Vec<u8>, SealedKeyError> {
    let mut seed = SensitiveBytes64::zeroed();
    sealed_seed(&prompt, &mut seed)?;
    sign_extrinsic_at(&seed, &account, &address, &message, spec_version, entropy)
}

/// `signature ‖ public_key` over a borsh NEAR `TransactionV0`, refused unless
/// the ML-DSA-65 account at `account` is `address` and is the key the
/// transaction declares. One prompt.
pub fn sealed_sign_near(
    account: AccountPath,
    address: String,
    transaction: Vec<u8>,
    entropy: Option<[u8; 32]>,
    prompt: String,
) -> Result<Vec<u8>, SealedKeyError> {
    let mut seed = SensitiveBytes64::zeroed();
    sealed_seed(&prompt, &mut seed)?;
    sign_near_at(&seed, &account, &address, &transaction, entropy)
}

/// The sealed phrase itself, for the screen that shows it. One prompt.
pub fn reveal_sealed_phrase(prompt: String) -> Result<String, SealedKeyError> {
    sealed_text(&prompt)
}

/// Removes the sealed phrase. Never prompts; a missing phrase is not an error.
pub fn delete_sealed_phrase() -> Result<(), SealedKeyError> {
    sealed_secret::delete(PHRASE_SLOT).map_err(refused)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::crypto::{
        generate_derived_keypair, set_default_ss58_prefix, sign_message_with_pubkey, to_account_id,
        verify_message,
    };
    use crate::api::near::{sign_near_transaction, tests::tx_for};
    use crate::sealed_secret::backend::device;

    const PHRASE: &str = "orchard answer curve patient visual flower maze noise retreat penalty cage small earth domain scan pitch bottom crunch theme club client swap slice raven";
    const PATH_87: &str = "m/44'/189189'/0'/0'/0'";
    const PATH_65: &str = "m/44'/189189'/0'/0'/1'";
    const ADDRESS_87: &str = "qzm5QCox8Dp5A3oSXZZYHD8YoYgPz7enykZb6RPUropdCyN5h";
    const ADDRESS_65: &str = "qzoyC4eRTrexYoutXABVsf61QJZxJim3iWvayRQwEjXWgA4mw";
    const SPEC: u32 = signing_context::EXTRINSIC_MIN_SPEC;

    fn account(path: &str, scheme: DilithiumScheme) -> AccountPath {
        AccountPath {
            path: path.to_string(),
            scheme,
        }
    }

    fn seed() -> SensitiveBytes64 {
        set_default_ss58_prefix(189);
        let mut seed = SensitiveBytes64::zeroed();
        stretch(PHRASE.to_string(), &mut seed).unwrap();
        seed
    }

    #[test]
    fn derives_the_known_accounts() {
        set_default_ss58_prefix(189);
        let keys = derive_account_keys(
            PHRASE.to_string(),
            vec![
                account(PATH_87, DilithiumScheme::MlDsa87),
                account(PATH_65, DilithiumScheme::MlDsa65),
            ],
        )
        .unwrap();

        assert_eq!(keys[0].address, ADDRESS_87);
        assert_eq!(keys[1].address, ADDRESS_65);
        for (key, (path, scheme)) in keys.iter().zip([
            (PATH_87, DilithiumScheme::MlDsa87),
            (PATH_65, DilithiumScheme::MlDsa65),
        ]) {
            let keypair = generate_derived_keypair(PHRASE.to_string(), path, scheme).unwrap();
            assert_eq!(key.public_key, keypair.public_key);
        }
    }

    #[test]
    fn refuses_a_phrase_or_path_that_derives_nothing() {
        let accounts = || vec![account(PATH_87, DilithiumScheme::MlDsa87)];
        let error = derive_account_keys("not a phrase".to_string(), accounts()).unwrap_err();
        assert_eq!(error.failure, SealedKeyFailure::Invalid);

        let bad_path = vec![account("m/44/x", DilithiumScheme::MlDsa87)];
        let error = derive_account_keys(PHRASE.to_string(), bad_path).unwrap_err();
        assert_eq!(error.failure, SealedKeyFailure::Invalid);
    }

    #[test]
    fn signs_an_extrinsic_exactly_as_the_key_pair_path_does() {
        let seed = seed();
        let message = b"payload";
        for (path, scheme, address) in [
            (PATH_87, DilithiumScheme::MlDsa87, ADDRESS_87),
            (PATH_65, DilithiumScheme::MlDsa65, ADDRESS_65),
        ] {
            let keypair = generate_derived_keypair(PHRASE.to_string(), path, scheme).unwrap();
            assert_eq!(to_account_id(&keypair), address);

            let signed =
                sign_extrinsic_at(&seed, &account(path, scheme), address, message, SPEC, None)
                    .unwrap();

            assert_eq!(
                signed,
                sign_message_with_pubkey(&keypair, message, None, SPEC)
            );
            let signature = &signed[..signed.len() - keypair.public_key.len()];
            assert!(verify_message(&keypair, message, signature, SPEC));
            assert!(!verify_message(&keypair, message, signature, SPEC - 1));
        }
    }

    #[test]
    fn refuses_to_sign_as_another_account() {
        let seed = seed();
        let error = sign_extrinsic_at(
            &seed,
            &account(PATH_87, DilithiumScheme::MlDsa87),
            ADDRESS_65,
            b"payload",
            SPEC,
            None,
        )
        .unwrap_err();
        assert_eq!(error.failure, SealedKeyFailure::WrongAccount);
    }

    #[test]
    fn signs_a_near_transaction_exactly_as_the_key_pair_path_does() {
        let seed = seed();
        let keypair =
            generate_derived_keypair(PHRASE.to_string(), PATH_65, DilithiumScheme::MlDsa65)
                .unwrap();
        let transaction = tx_for(&keypair);
        let ml65 = account(PATH_65, DilithiumScheme::MlDsa65);

        let signed = sign_near_at(&seed, &ml65, ADDRESS_65, &transaction, None).unwrap();
        assert_eq!(
            signed,
            sign_near_transaction(&keypair, transaction.clone(), None).unwrap()
        );

        let error = sign_near_at(&seed, &ml65, ADDRESS_87, &transaction, None).unwrap_err();
        assert_eq!(error.failure, SealedKeyFailure::WrongAccount);

        let ml87 = account(PATH_87, DilithiumScheme::MlDsa87);
        let error = sign_near_at(&seed, &ml87, ADDRESS_87, &transaction, None).unwrap_err();
        assert_eq!(error.failure, SealedKeyFailure::Invalid);
    }

    fn seal_on_a_device_enforcing(policy: SealPolicy) {
        set_default_ss58_prefix(189);
        device(|d| d.enrolled = Some(policy));
        seal_phrase(PHRASE.to_string(), policy).unwrap();
    }

    fn sign_sealed() -> Result<Vec<u8>, SealedKeyError> {
        sealed_sign_extrinsic(
            account(PATH_87, DilithiumScheme::MlDsa87),
            ADDRESS_87.to_string(),
            b"payload".to_vec(),
            SPEC,
            None,
            "prompt".to_string(),
        )
    }

    #[test]
    fn uses_the_sealed_phrase_behind_one_prompt_per_operation() {
        seal_on_a_device_enforcing(SealPolicy::Biometry);
        assert_eq!(sealed_phrase_policy().unwrap(), Some(SealPolicy::Biometry));
        assert_eq!(device(|d| d.prompts), 0);

        let keypair =
            generate_derived_keypair(PHRASE.to_string(), PATH_87, DilithiumScheme::MlDsa87)
                .unwrap();
        assert_eq!(
            sign_sealed().unwrap(),
            sign_message_with_pubkey(&keypair, b"payload", None, SPEC)
        );
        assert_eq!(device(|d| d.prompts), 1);

        let keys = sealed_account_keys(
            vec![account(PATH_65, DilithiumScheme::MlDsa65)],
            "prompt".to_string(),
        )
        .unwrap();
        assert_eq!(keys[0].address, ADDRESS_65);
        assert_eq!(reveal_sealed_phrase("prompt".to_string()).unwrap(), PHRASE);
        assert_eq!(device(|d| d.prompts), 3);
    }

    #[test]
    fn signs_nothing_when_the_device_does_not_release_the_phrase() {
        seal_on_a_device_enforcing(SealPolicy::DevicePasscode);
        for (refusal, failure) in [
            (Failure::Cancelled, SealedKeyFailure::Cancelled),
            (Failure::NotRecognised, SealedKeyFailure::NotRecognised),
        ] {
            device(|d| d.refusals = vec![refusal]);
            assert_eq!(sign_sealed().unwrap_err().failure, failure);
        }

        delete_sealed_phrase().unwrap();
        assert_eq!(
            sign_sealed().unwrap_err().failure,
            SealedKeyFailure::Missing
        );
        assert_eq!(sealed_phrase_policy().unwrap(), None);
    }

    #[test]
    fn seals_only_under_a_policy_the_device_enforces() {
        assert_eq!(seal_policy_available().unwrap(), None);
        let error = seal_phrase(PHRASE.to_string(), SealPolicy::DevicePasscode).unwrap_err();
        assert_eq!(error.failure, SealedKeyFailure::Unavailable);
        assert_eq!(sealed_phrase_policy().unwrap(), None);
    }

    #[test]
    fn moves_the_sealed_phrase_behind_a_biometric_enrolled_later() {
        seal_on_a_device_enforcing(SealPolicy::DevicePasscode);
        device(|d| d.enrolled = Some(SealPolicy::Biometry));
        assert_eq!(seal_policy_available().unwrap(), Some(SealPolicy::Biometry));

        reseal_phrase(SealPolicy::Biometry, "prompt".to_string()).unwrap();

        assert_eq!(sealed_phrase_policy().unwrap(), Some(SealPolicy::Biometry));
        assert_eq!(reveal_sealed_phrase("prompt".to_string()).unwrap(), PHRASE);
    }
}
