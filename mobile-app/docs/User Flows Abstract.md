# Quantus Wallet - Functional Requirements (Abstract)

This document defines **what** the wallet must do, not **how** to implement it. Each capability describes the user's goal, required inputs, and expected outputs. UI designers and developers can implement these capabilities using any screen flow or interaction pattern that best serves the user experience.

Numbers correspond to the Implementation spec for cross-reference.

---

## 1. Create Wallet
**Goal:** User establishes a new wallet from scratch

**User Inputs:**
- Account name (optional, can default)

**Wallet Outputs:**
- Generated 24-word recovery phrase
- Derived account address
- Human-readable checkphrase (address verification aid)

**Constraints:**
- Phrase stored securely on device

---

## 2. Import Wallet
**Goal:** User restores access to existing wallet using recovery phrase

**User Inputs:**
- Recovery phrase (12 or 24 words)

**Wallet Outputs:**
- Derived account address(es)
- Discovered on-chain accounts with balances

**Constraints:**
- Must validate phrase format before proceeding
- Should discover all derived accounts with on-chain activity

---

## 3. Send (Immediate)
**Goal:** User transfers funds to another address with immediate finality

**User Inputs:**
- Recipient address
- Amount

**Wallet Outputs:**
- Chain Fee (shown before send, not adjustable)
- Transaction submitted to chain
- Transaction hash
- Updated pending balance

**Async Resolution:**
- Transaction status: pending → confirmed/failed
- Typical confirmation: 20 seconds to several minutes

---

## 4. Send (Reversible)
**Goal:** User transfers funds with a cancellation window

**User Inputs:**
- Recipient address
- Amount
- Reversibility duration

**Wallet Outputs:**
- Chain Fee (shown before send, not adjustable)
- Transaction submitted to chain
- Transaction ID (for cancellation)
- Scheduled execution time
- Funds locked during reversibility window, deducted at send
- Free balance is changed immediately, changed back if transfer is reversed

**Async Resolution:**
- Status: pending → scheduled → executed/cancelled/failed
- Countdown timer until execution

---

## 5. Cancel Reversible Transfer
**Goal:** User cancels an outgoing reversible transfer before execution

**User Inputs:**
- Transaction selection
- Confirmation

**Wallet Outputs:**
- Cancellation submitted to chain
- Funds returned to sender

**Constraints:**
- Only possible while countdown is active
- An account can only cancel their own transfer, not another account's transfer
- Cannot cancel after execution

---

## 6. Receive
**Goal:** User shares their address to receive incoming funds

**User Inputs:** None

**Wallet Outputs:**
- QR code of address
- Copyable address
- Copyable checkphrase
- Shareable link/text

---

## 7. Enable High Security
**Goal:** User activates theft deterrence on an account (permanent)

**User Inputs:**
- Guardian account address
- Safeguard window duration (mandatory delay for all future sends)
- Confirmation (acknowledging irreversibility)

**Wallet Outputs:**
- High security configuration submitted to chain
- Account permanently marked as high-security

**Constraints:**
- Cannot be disabled once enabled
- All future sends from this account must use the safeguard window
- Requires sufficient balance for transaction fee

---

## 8. Intercept Transaction (Guardian)
**Goal:** Guardian pulls funds from a pending transfer on an entrusted account

**User Inputs:**
- Transaction selection (select entrusted reversible transaction)
- Confirmation

**Wallet Outputs:**
- Interception submitted to chain
- Funds transferred to guardian account
- Original transaction cancelled

**Constraints:**
- Only guardian account can intercept
- Only during reversibility window

---

## 9. View Recovery Phrase
**Goal:** User retrieves their recovery phrase for backup purposes

**User Inputs:**
- Wallet selection (if multiple wallets exist)

**Wallet Outputs:**
- Recovery phrase (12 or 24 words)

**Constraints:**
- Should require explicit user action to reveal (not shown by default)
- Could require biometrics auth
- Copy functionality required

---

## 10. Enable Device Authentication 
**Goal:** User secures app access with biometrics/PIN

**User Inputs:**
- Enable toggle or could be always on (no user choice)
- Biometric/PIN verification

**Wallet Outputs:**
- Authentication requirement saved locally

**Constraints:**
- Could be done in settings or else just at app start without option to not do it.

---

## 10a. Configure Authentication Timeout (optional)
**Goal:** User sets how long before re-authentication is required

**User Inputs:**
- Timeout selection (immediate, 1min, 5min, 15min, 30min, 1hr)

**Wallet Outputs:**
- Timeout preference saved locally

**Note:** Could also leave this out and just set to a reasonable default value.

---

## 10b. Disable Device Authentication (optional)
**Goal:** User removes biometric/PIN requirement

**User Inputs:**
- Disable toggle
- Current authentication verification

**Wallet Outputs:**
- Authentication requirement removed

**Note:** This may not be offered - authentication could be mandatory.

---

## 11. Submit Referral Code
**Goal:** New user links to a referrer for rewards

**User Inputs:**
- Referral code (5-word phrase or prefilled from deep link)

**Wallet Outputs:**
- Referral recorded on backend
- Confirmation of submission

---

## 12. Opt-In to Reward Program
**Goal:** User joins the rewards/quests program

**User Inputs:**
- Opt-in confirmation

**Wallet Outputs:**
- Participation status
- Queue position number

---

## 13. Manage Accounts (overview)
**Goal:** User manages their accounts and wallets

This section covers multiple related capabilities for account/wallet management.

---

## 13a. Add Wallet
**Goal:** User adds another wallet (when they already have one)

**User Inputs:**
- Choice: create new or import existing
- If create: account name (optional)
- If import: recovery phrase (12 or 24 words)

**Wallet Outputs:**
- New wallet added with its own mnemonic
- First account derived from new wallet
- Account address and checkphrase

**Note:** This is different from flow #1 (Create Wallet) which is for first-time users. This flow is accessed from account management when user already has a wallet.

---

## 13b. Add Account
**Goal:** User creates a new account derived from an existing wallet

**User Inputs:**
- Account name

**Wallet Outputs:**
- New account address (derived from wallet mnemonic using next index)
- Human-readable checkphrase

**Constraints:**
- Account derived using standard derivation path
- Requires existing wallet with stored mnemonic

---

## 13c. Switch Account
**Goal:** User changes which account is currently active for transactions

**User Inputs:**
- Account selection

**Wallet Outputs:**
- Active account changed
- UI reflects new account's balance/history

---

## 13d. Edit Account
**Goal:** User modifies account metadata

**User Inputs:**
- New account name

**Wallet Outputs:**
- Updated account name stored locally

---

## 13e. View Account Details
**Goal:** User sees full information about an account

**User Inputs:**
- Account selection

**Wallet Outputs:**
- Account name
- Full address
- Human-readable checkphrase
- Current balance
- Account type/tags (High Security, Guardian, Entrusted, Hardware)

---

## 14. Add Hardware Wallet
**Goal:** User connects an external signing device (e.g., Keystone)

**User Inputs:**
- QR code scan from hardware device
- Account name

**Wallet Outputs:**
- Hardware account address added
- Account marked as hardware-signed

**Constraints:**
- Transactions require QR-based signing workflow
- Private keys never touch the app

---

## 14a. Remove Hardware Account
**Goal:** User disconnects a hardware wallet account

**User Inputs:**
- Confirmation

**Wallet Outputs:**
- Account removed from local storage

---

## 15. View Transaction History
**Goal:** User sees their transaction history

**User Inputs:**
- Optional: account filter
- Optional: transaction type filter

**Wallet Outputs:**
- List of transactions showing:
  - Type (send/receive/reward)
  - Amount
  - Counterparty
  - Status (pending/confirmed/failed/scheduled/executed/cancelled)
  - Timestamp
  - For reversible: remaining time

**Async Updates:**
- Background refresh (typically 60 seconds)
- Aggressive refresh for pending/reversible items

---

## 16. View Transaction Details
**Goal:** User sees complete information about a specific transaction

**User Inputs:**
- Transaction selection

**Wallet Outputs:**
- Full amount
- Counterparty address and checkphrase
- Transaction status
- Transaction hash
- Block explorer link
- For reversible: countdown timer
- For failed: error message

---

## 17. Retry Failed Transaction
**Goal:** User resubmits a transaction that previously failed

**User Inputs:**
- Failed transaction selection

**Wallet Outputs:**
- New transaction submitted with same parameters
- New transaction hash

---

## 18. Configure Notification Preferences
**Goal:** User manages which notifications they receive.

**User Inputs:**
- Toggle for each notification type:
  - Transaction failures
  - Low balance alerts
  - Reversible transaction reminders
  - Incoming transactions

**Wallet Outputs:**
- Preferences saved locally

---

## 18a. View Notifications
**Goal:** User sees their notification history

**User Inputs:**
- Optional: account filter

**Wallet Outputs:**
- List of notifications with:
  - Type/severity
  - Message
  - Timestamp
  - Related account
- Ability to dismiss individual/all

---

## 19. Share/Invite Others
**Goal:** User invites others to earn referral rewards

**User Inputs:** None

**Wallet Outputs:**
- Shareable text with referral code/link
- System share sheet

---

## 20. Reset Wallet
**Goal:** User removes all wallet data from device

**User Inputs:**
- Explicit confirmation and warning
- Possibly prompt to securely store the mnemonic

**Wallet Outputs:**
- All local data cleared
- Return to initial/onboarding state

**Constraints:**
- Must warn user this is irreversible
- Must require deliberate confirmation (prevent accidental reset)

---

## Additional Capabilities

### View Reward Status
**Goal:** User checks their reward program standing

**User Inputs:** None

**Wallet Outputs:**
- Opt-in position
- Associated accounts
- Available quests
- Quest completion status

---

### View High Security Configuration
**Goal:** User views their high security settings

**User Inputs:**
- Account selection

**Wallet Outputs:**
- Guardian account address
- Safeguard window duration
- List of entrusted accounts (if guardian)

---

## System Capabilities (not direct user flows)

### Fee Estimation (on any chain transaction)
**Goal:** System calculates network fee before user confirms transaction

**Inputs:**
- Recipient address
- Amount
- Transfer type (immediate/reversible)
- Reversibility duration (if applicable)

**Outputs:**
- Estimated fee amount
- Current block height (for transaction validity)

**Constraints:**
- Must recalculate when inputs change
- Fee may change between estimate and submission

---

### Address Validation
**Goal:** Verify a recipient address is valid before sending

**Inputs:**
- Address string

**Outputs:**
- Valid/invalid status
- Human-readable checkphrase (if valid)

---

### View Balance
**Goal:** User sees their current funds

**Inputs:**
- Account selection

**Outputs:**
- Total balance
- Available balance (accounting for pending outgoing)
- Locked/reserved balance (if any)

**Async Updates:**
- Background polling
- Immediate optimistic updates after transactions

---

## Common Async Patterns

All chain transactions follow this lifecycle:

1. **Submission:** Transaction sent to network
2. **Pending:** Awaiting block inclusion (optimistic UI update)
3. **In Block:** Included in block, awaiting finalization
4. **Confirmed/Failed:** Final state reached

**Timing:**
- Block inclusion: typically 20 seconds to several minutes
- Reversible execution: user-defined delay
- Background sync: 60-second intervals
- Active transaction tracking: 10-second intervals
- Reversible execution detection: 5-second intervals near deadline

**Optimistic Updates:**
- Balance reduced immediately on send
- Transaction appears in history immediately
- Reverted on failure

---

## Data Persistence Summary

| Data | Storage | Notes |
|------|---------|-------|
| Recovery phrase | Secure local storage | Encrypted |
| Account metadata | Local storage | Names, derivation indices |
| Authentication settings | Local storage | Biometric preferences |
| Notification preferences | Local storage | |
| Transaction history | Chain (via indexer) | Fetched on demand |
| Pending transactions | Local + chain | Reconciled on sync |
| High security config | Chain | Permanent once set |
| Referral data | Backend | API-based |

---

## External Integrations

| Integration | Purpose |
|-------------|---------|
| Blockchain RPC | Transaction submission, balance queries |
| Subsquid/Indexer | Transaction history, account discovery |
| Block Explorer | Transaction detail links |
| Backend API | Referrals, rewards program |
| Deep Links | Referral codes, address sharing |

---

This specification defines the functional requirements without prescribing UI patterns. Implementers should design flows that best serve their users while ensuring all inputs are collected and outputs are properly displayed.
