//! Self-wiping buffers for secret material. Every wipe ends in `black_box`,
//! so the compiler must assume the zeros are observed and cannot elide the
//! stores (same construction as qp-poseidon-core's internal state wipe).

/// Element types that can hold secret material.
pub(crate) trait Wipe {
    fn wipe(&mut self);
}

impl Wipe for u8 {
    fn wipe(&mut self) {
        *self = 0;
    }
}

impl Wipe for qp_poseidon_core::Goldilocks {
    fn wipe(&mut self) {
        *self = qp_poseidon_core::Goldilocks::ZERO;
    }
}

impl Wipe for p3_goldilocks::Goldilocks {
    fn wipe(&mut self) {
        *self = <p3_goldilocks::Goldilocks as p3_field::PrimeCharacteristicRing>::ZERO;
    }
}

impl<T: Wipe> Wipe for Vec<T> {
    fn wipe(&mut self) {
        wipe(self.as_mut_slice());
    }
}

impl<T: Wipe, const N: usize> Wipe for [T; N] {
    fn wipe(&mut self) {
        wipe(self.as_mut_slice());
    }
}

/// A secret paired with its public source label.
impl<T: Wipe> Wipe for (T, String) {
    fn wipe(&mut self) {
        self.0.wipe();
    }
}

/// Zero every element, resistant to dead-store elimination.
pub(crate) fn wipe<T: Wipe>(items: &mut [T]) {
    for item in items.iter_mut() {
        item.wipe();
    }
    core::hint::black_box(items);
}

/// Heap buffer of secret-bearing elements, wiped on drop (so success, error,
/// and panic paths all scrub). Wrap an existing `Vec` or reserve the full
/// capacity before pushing: a growing `Vec` frees its old block unscrubbed.
pub(crate) struct SensitiveVec<T: Wipe>(pub(crate) Vec<T>);

impl<T: Wipe> SensitiveVec<T> {
    pub(crate) fn with_capacity(capacity: usize) -> Self {
        Self(Vec::with_capacity(capacity))
    }

    pub(crate) fn push(&mut self, item: T) {
        debug_assert!(
            self.0.len() < self.0.capacity(),
            "SensitiveVec must be pre-sized"
        );
        self.0.push(item);
    }
}

impl<T: Wipe> std::ops::Deref for SensitiveVec<T> {
    type Target = [T];
    fn deref(&self) -> &[T] {
        &self.0
    }
}

impl<T: Wipe> Drop for SensitiveVec<T> {
    fn drop(&mut self) {
        wipe(&mut self.0);
    }
}

/// Owned secret text (a mnemonic) wiped on drop. Takes the `String`'s heap
/// buffer without copying it.
pub(crate) struct SensitiveString(SensitiveVec<u8>);

impl SensitiveString {
    pub(crate) fn new(s: String) -> Self {
        Self(SensitiveVec(s.into_bytes()))
    }

    pub(crate) fn as_str(&self) -> &str {
        std::str::from_utf8(&self.0).expect("String bytes are UTF-8")
    }
}
