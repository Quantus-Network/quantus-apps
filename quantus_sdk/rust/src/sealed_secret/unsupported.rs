//! Platforms with no sealed store: every call says so.

use super::{refusal, Failure, Refusal, SealPolicy};
use crate::sensitive::SensitiveVec;

fn unsupported<T>() -> Result<T, Refusal> {
    Err(refusal(
        Failure::Platform,
        "This platform has no sealed store",
    ))
}

pub(crate) fn enforces(_policy: SealPolicy) -> Result<bool, Refusal> {
    unsupported()
}

pub(crate) fn stored(_slot: &str) -> Result<Option<SealPolicy>, Refusal> {
    unsupported()
}

pub(crate) fn store(_slot: &str, _secret: &[u8], _policy: SealPolicy) -> Result<(), Refusal> {
    unsupported()
}

pub(crate) fn read(_slot: &str, _prompt: &str) -> Result<SensitiveVec<u8>, Refusal> {
    unsupported()
}

pub(crate) fn delete(_slot: &str) -> Result<(), Refusal> {
    unsupported()
}
