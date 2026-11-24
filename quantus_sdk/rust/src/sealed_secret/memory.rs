//! The sealed store of the unit tests: one thread's memory standing in for a
//! device, with its prompts counted and its next reads refusable.

use super::{refusal, Failure, Refusal, SealPolicy};
use crate::sensitive::SensitiveVec;
use std::cell::RefCell;
use std::collections::HashMap;

#[derive(Default)]
pub(crate) struct Device {
    /// The strongest policy the device enforces; `None` is no screen lock.
    pub(crate) enrolled: Option<SealPolicy>,
    pub(crate) prompts: u32,
    /// What the coming reads answer, in order, instead of releasing.
    pub(crate) refusals: Vec<Failure>,
    /// Reads that release normally before `refusals` starts to apply.
    pub(crate) prompts_before_refusal: u32,
    slots: HashMap<String, (SealPolicy, Vec<u8>)>,
}

thread_local! {
    static DEVICE: RefCell<Device> = RefCell::new(Device::default());
}

pub(crate) fn device<T>(change: impl FnOnce(&mut Device) -> T) -> T {
    DEVICE.with(|device| change(&mut device.borrow_mut()))
}

fn enforces(enrolled: Option<SealPolicy>, policy: SealPolicy) -> bool {
    enrolled == Some(SealPolicy::Biometry) || enrolled == Some(policy)
}

pub(crate) fn available() -> Result<Option<SealPolicy>, Refusal> {
    Ok(device(|d| d.enrolled))
}

pub(crate) fn stored(slot: &str) -> Result<Option<SealPolicy>, Refusal> {
    Ok(device(|d| d.slots.get(slot).map(|sealed| sealed.0)))
}

pub(crate) fn store(slot: &str, secret: &[u8], policy: SealPolicy) -> Result<(), Refusal> {
    device(|d| {
        if !enforces(d.enrolled, policy) {
            return Err(refusal(Failure::Unavailable, "Not enforceable"));
        }
        d.slots.insert(slot.to_string(), (policy, secret.to_vec()));
        Ok(())
    })
}

pub(crate) fn read(slot: &str, _prompt: &str) -> Result<SensitiveVec<u8>, Refusal> {
    device(|d| {
        let Some((_, secret)) = d.slots.get(slot) else {
            return Err(refusal(Failure::Missing, "Empty slot"));
        };
        d.prompts += 1;
        if d.prompts_before_refusal > 0 {
            d.prompts_before_refusal -= 1;
        } else if !d.refusals.is_empty() {
            return Err(refusal(d.refusals.remove(0), "Refused by the test"));
        }
        Ok(SensitiveVec(secret.clone()))
    })
}

pub(crate) fn delete(slot: &str) -> Result<(), Refusal> {
    device(|d| d.slots.remove(slot));
    Ok(())
}
