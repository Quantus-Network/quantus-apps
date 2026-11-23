//! The cold wallet's signing key, used without handing key material to Dart.
//!
//! On iOS the recovery phrase lives in the sealed keychain item
//! ([`crate::sealed_phrase`]). Each `sealed_*` call takes it out for that one
//! operation, behind one biometric prompt, and wipes it before returning:
//! only public keys and signatures cross the bridge. None of them is `sync`,
//! because the prompt blocks and must not hold the UI thread.

use crate::api::crypto::{address_of, dispatch, DilithiumScheme};
use crate::api::near::{sign_declared_transaction, ML_DSA_65_ONLY};
use crate::sealed_phrase;
use crate::sensitive::SensitiveVec;
use crate::signing_context;
use qp_rusty_crystals_hdwallet::{mnemonic_to_seed, SensitiveBytes32, SensitiveBytes64};

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
    /// The biometric prompt was dismissed.
    Cancelled,
    /// No biometric match, or biometrics are locked out.
    NotRecognised,
    /// No sealed phrase on this device: never stored, or destroyed by iOS
    /// when the passcode was turned off or the enrolled biometrics changed.
    Missing,
    /// This platform has no sealed store.
    Unsupported,
    /// The path derives another account than the one the caller named.
    WrongAccount,
    /// The phrase, path or request cannot be used.
    Invalid,
    /// The keychain refused for another reason; the detail carries its status.
    Keychain,
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

fn keychain(status: i32) -> SealedKeyError {
    let failure = match status {
        sealed_phrase::USER_CANCELED => SealedKeyFailure::Cancelled,
        sealed_phrase::AUTH_FAILED => SealedKeyFailure::NotRecognised,
        sealed_phrase::ITEM_NOT_FOUND => SealedKeyFailure::Missing,
        sealed_phrase::UNIMPLEMENTED => SealedKeyFailure::Unsupported,
        _ => SealedKeyFailure::Keychain,
    };
    failed(failure, format!("Keychain status {status}"))
}

/// Stretches `phrase` into `seed`. The phrase is wiped on every path.
fn stretch(phrase: String, seed: &mut SensitiveBytes64) -> Result<(), SealedKeyError> {
    mnemonic_to_seed(phrase, None, seed).map_err(invalid)
}

/// Takes the sealed phrase out for one operation. Prompts.
fn sealed_text() -> Result<String, SealedKeyError> {
    let mut phrase = sealed_phrase::read().map_err(keychain)?;
    String::from_utf8(std::mem::take(&mut phrase.0)).map_err(|error| {
        drop(SensitiveVec(error.into_bytes()));
        invalid("The sealed phrase is not text")
    })
}

fn sealed_seed(seed: &mut SensitiveBytes64) -> Result<(), SealedKeyError> {
    stretch(sealed_text()?, seed)
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
/// restore, before it is sealed. Never touches the sealed item.
pub fn derive_account_keys(
    phrase: String,
    accounts: Vec<AccountPath>,
) -> Result<Vec<AccountPublicKey>, SealedKeyError> {
    let mut seed = SensitiveBytes64::zeroed();
    stretch(phrase, &mut seed)?;
    public_keys(&seed, &accounts)
}

/// Whether a sealed phrase is on this device. Never prompts.
pub fn sealed_phrase_exists() -> Result<bool, SealedKeyError> {
    sealed_phrase::exists().map_err(keychain)
}

/// Seals `phrase`, replacing any phrase already sealed. Never prompts.
pub fn seal_phrase(phrase: String) -> Result<(), SealedKeyError> {
    let phrase = SensitiveVec(phrase.into_bytes());
    sealed_phrase::store(&phrase).map_err(keychain)
}

/// Public keys of `accounts` under the sealed phrase. One prompt for the batch.
pub fn sealed_account_keys(
    accounts: Vec<AccountPath>,
) -> Result<Vec<AccountPublicKey>, SealedKeyError> {
    let mut seed = SensitiveBytes64::zeroed();
    sealed_seed(&mut seed)?;
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
) -> Result<Vec<u8>, SealedKeyError> {
    let mut seed = SensitiveBytes64::zeroed();
    sealed_seed(&mut seed)?;
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
) -> Result<Vec<u8>, SealedKeyError> {
    let mut seed = SensitiveBytes64::zeroed();
    sealed_seed(&mut seed)?;
    sign_near_at(&seed, &account, &address, &transaction, entropy)
}

/// The sealed phrase itself, for the screen that shows it. One prompt.
pub fn reveal_sealed_phrase() -> Result<String, SealedKeyError> {
    sealed_text()
}

/// Removes the sealed phrase. Never prompts; a missing phrase is not an error.
pub fn delete_sealed_phrase() -> Result<(), SealedKeyError> {
    sealed_phrase::delete().map_err(keychain)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::crypto::{
        generate_derived_keypair, set_default_ss58_prefix, sign_message_with_pubkey, to_account_id,
        verify_message,
    };
    use crate::api::near::{sign_near_transaction, tests::tx_for};

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

    #[test]
    fn has_no_sealed_store_off_ios() {
        assert_eq!(
            sealed_phrase_exists().unwrap_err().failure,
            SealedKeyFailure::Unsupported
        );
        assert_eq!(
            seal_phrase(PHRASE.to_string()).unwrap_err().failure,
            SealedKeyFailure::Unsupported
        );
        assert_eq!(
            reveal_sealed_phrase().unwrap_err().failure,
            SealedKeyFailure::Unsupported
        );
        assert_eq!(
            delete_sealed_phrase().unwrap_err().failure,
            SealedKeyFailure::Unsupported
        );
    }
}
