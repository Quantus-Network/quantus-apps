# Quantus Wallet User Flows

## 1. Create New Wallet

**Intention:** First-time user wants to create a new wallet and account

**User Flow:**
1. User opens app and lands on Welcome Screen
2. User taps "Create New Wallet"
3. System generates a 12-word mnemonic phrase
4. User inputs account name (defaults to "Account 1")
5. User sees checkphrase and account address displayed
6. User can tap "Show Recovery Phrase" to view and optionally copy the mnemonic
7. User taps "Create Wallet"
8. System saves mnemonic to secure storage
9. User is navigated to home screen with optional referral prompt

**Data In:**
- Account name (user input)

**Data to Chain:**
- None (local wallet creation only)

**Data Out:**
- Mnemonic phrase (generated, stored locally)
- Account address (derived from mnemonic)
- Human-readable checkphrase (derived from address)

**Pending States:** None - this is a local operation

---

## 2. Import Wallet

**Intention:** User wants to restore an existing wallet from recovery phrase

**User Flow:**
1. User taps "Import Wallet" from Welcome Screen
2. User enters 12 or 24 word recovery phrase
3. User taps "Import Wallet"
4. System validates mnemonic format
5. System discovers existing accounts on-chain (account discovery)
6. System shows "Discovering existing accounts..." loading state
7. User is navigated to home screen

**Data In:**
- Recovery phrase (12 or 24 words)

**Data to Chain:**
- None

**Data Out:**
- Account address(es) derived from phrase
- Discovered accounts with balances (queried from chain)

**Pending States:** Account discovery queries the chain but is not a transaction

---

## 3. Send (Immediate)

**Intention:** User wants to send coins immediately without reversibility window

**User Flow:**
1. User taps Send from home screen
2. User inputs destination address (via typing, paste, scan QR, or recent addresses)
3. System validates address and displays human-readable checkphrase
4. User inputs amount
5. User can tap "Max" to auto-fill maximum sendable amount
6. User selects "Now" in reversibility selector
7. System fetches network fee estimate
8. User taps send button
9. Confirmation sheet appears showing: amount, recipient checkphrase, recipient address, network fee
10. User taps "Confirm"
11. Progress state shown with "TRANSACTION IN PROGRESS"
12. Completion state shown with "SENDING" and done button
13. User returns to home screen

**Data In:**
- Recipient address
- Amount (BigInt)
- Selected reversibility mode (none)

**Data to Chain:**
- Balances.transferKeepAlive extrinsic with:
  - Recipient address
  - Amount

**Data Out:**
- Transaction hash (extrinsic hash)
- Estimated fee (pre-submission)

**Pending States:**
- Transaction appears in pending transactions list immediately after submission
- Status: `created` → `inBlock` → `confirmed` (or `failed`)
- Typically takes 20 seconds to a few minutes for block inclusion
- Balance is optimistically reduced by amount + fee immediately
- History polling service monitors for confirmation (10s intervals for inBlock tracking)

---

## 4. Send (Reversible)

**Intention:** User wants to send coins with a reversibility window during which they can cancel

**User Flow:**
1. User taps Send from home screen
2. User inputs destination address
3. System validates address and displays human-readable checkphrase
4. User inputs amount
5. User selects reversible time duration (e.g., "10 min", can tap to edit)
6. Time picker sheet allows: days (0-7), hours (0-23), minutes (0-59)
7. System fetches network fee estimate for reversible transfer
8. User taps send button
9. Confirmation sheet shows: amount, recipient, network fee, "Reversible for: X hours, Y minutes"
10. User taps "Confirm"
11. Progress → Complete states
12. Transaction appears in history with countdown timer

**Data In:**
- Recipient address
- Amount
- Reversibility duration (seconds)

**Data to Chain:**
- QpScheduler.scheduleReversibleTransfer extrinsic with:
  - Recipient address
  - Amount
  - Delay (as timestamp offset)

**Data Out:**
- Transaction ID (for cancellation)
- Extrinsic hash
- Scheduled execution time

**Pending States:**
- Transaction appears immediately in pending state
- After block inclusion: shows as "SCHEDULED" reversible transfer
- Countdown timer displays remaining time until execution
- Status flow: `created` → `inBlock` → `SCHEDULED` → `EXECUTED` (or `CANCELLED`)
- Aggressive polling (5s) when timer approaches zero

---

## 5. Reverse/Cancel Transaction

**Intention:** User wants to cancel a reversible transaction before it executes

**User Flow:**
1. User taps on a reversible transaction in history (with active countdown)
2. Reversible Transaction Action Sheet appears showing:
   - Remaining time countdown
   - Recipient details
   - Amount
3. User taps "Reverse" button
4. Confirmation prompt: "Are you sure you want to reverse this tx?"
5. User taps "Reverse" again to confirm
6. System submits cancellation
7. UI updates to show "Transaction Reversed"

**Data In:**
- Transaction ID (hex encoded)

**Data to Chain:**
- QpScheduler.cancelReversibleTransfer extrinsic with:
  - Transaction ID

**Data Out:**
- Updated transaction status (CANCELLED)

**Pending States:**
- Cancellation submission is immediate
- UI optimistically updates status to CANCELLED
- Background polling confirms final status
- Funds return to sender's available balance

---

## 6. Receive

**Intention:** User wants to share their address to receive coins

**User Flow:**
1. User taps Receive from home screen
2. Receive sheet displays:
   - QR code of account address
   - Account name with gradient icon
   - Human-readable checkphrase (copyable)
   - Full address (copyable, chunked for readability)
3. User can tap copy icons to copy address or checkphrase
4. User can tap "Share Wallet" to open system share sheet
5. Share includes: address, checkphrase, and deep link URL

**Data In:** None

**Data to Chain:** None

**Data Out:**
- Account address (displayed/shared)
- Checkphrase (displayed/shared)
- Share link: `{websiteBaseUrl}/account?id={accountId}`

**Pending States:** None - display only

---

## 7. Enable High Security

**Intention:** User wants to enable theft deterrence features on an account (irreversible)

**User Flow:**
1. User navigates to Account Settings → High Security
2. High Security Get Started screen explains the feature
3. System checks balance for fee requirement
4. User taps "Start"
5. **Step 1 - Guardian Account:** User inputs guardian address (paste/scan QR)
6. System validates address and shows checkphrase
7. User taps "Next"
8. **Step 2 - Safeguard Window:** User selects delay time (days, hours, minutes)
9. This sets the mandatory reversibility window for all future sends
10. User taps "Next"
11. **Step 3 - Summary:** Shows high security account, guardian account, safeguard window
12. User taps "Next"
13. **Confirmation sheet** with warning: "Once enabled, this cannot be undone"
14. User taps "Confirm"
15. Transaction submitted to chain
16. Success sheet shown with "High Security Enabled"

**Data In:**
- Guardian account address
- Safeguard window duration (seconds)

**Data to Chain:**
- HighSecurity.enableHighSecurity extrinsic with:
  - Guardian address
  - Safeguard window (as duration)

**Data Out:**
- High security configuration stored on-chain
- Account now flagged as high-security

**Pending States:**
- Submission pending → confirmed
- Once confirmed, all future sends from this account must use the safeguard window
- Cannot be disabled after enablement

---

## 8. Intercept Transaction (Guardian)

**Intention:** Guardian account holder wants to intercept a transaction from an entrusted account they guard

**User Flow:**
1. Guardian sees incoming reversible transfer in notifications/history from entrusted account
2. Guardian taps on transaction
3. Action sheet shows "Intercept Transaction" option
4. Details shown: amount, original recipient
5. Guardian taps "Intercept"
6. Confirmation: "Are you sure you want to intercept this transaction and pull it to your account?"
7. Guardian taps "Intercept" to confirm
8. Transaction is cancelled and funds pulled to guardian account
9. UI shows "Transaction Intercepted"

**Data In:**
- Transaction ID

**Data to Chain:**
- HighSecurity.interceptTransaction extrinsic with:
  - Transaction ID

**Data Out:**
- Funds transferred to guardian account
- Original transaction cancelled

**Pending States:**
- Submission pending → confirmed
- Intercepted status shown on transaction

---

## 9. View Recovery Phrase

**Intention:** User wants to view their wallet's recovery phrase for backup

**User Flow:**
1. User navigates to Settings → Show Recovery Phrase
2. If multiple wallets exist, user selects which wallet
3. Recovery phrase screen shows blurred/hidden grid
4. User taps "Hold to Reveal"
5. Mnemonic words displayed in numbered grid
6. User can tap "Copy to Clipboard"
7. User taps "Done" to close

**Data In:** None (reads from secure storage)

**Data to Chain:** None

**Data Out:**
- Recovery phrase displayed to user

**Pending States:** None

---

## 10. Enable/Disable Biometric Authentication

**Intention:** User wants to secure app access with device biometrics

**User Flow:**
1. User navigates to Settings → Authentication
2. Toggle switch for "Authentication" shown
3. User toggles ON
4. System checks biometric availability
5. System prompts for biometric authentication (Face ID/Touch ID/PIN)
6. If successful, authentication is enabled
7. User can configure timeout: Immediately, 1 min, 5 min, 15 min, 30 min, 1 hour
8. App will require authentication after timeout period when returning

**Data In:**
- Enable/disable toggle
- Timeout duration selection

**Data to Chain:** None (local setting)

**Data Out:**
- Setting stored locally

**Pending States:** None

---

## 11. Submit Referral Code

**Intention:** New user wants to link their account to a referrer

**User Flow:**
1. Referral sheet appears after wallet creation (or via Settings → Referral)
2. If deep-linked with referral code, shows prefilled code
3. Otherwise, user manually enters 5-word referral code
4. User taps "Submit"
5. System sends referral to backend
6. Success: sheet closes
7. User and referrer receive reward program points

**Data In:**
- Referral code (5 words)

**Data to Chain:** None (backend API call)

**Data Out:**
- Referral recorded on backend
- Points credited

**Pending States:** API submission only

---

## 12. Opt-In to Reward Program (Quests)

**Intention:** User wants to participate in the reward program

**User Flow:**
1. User navigates to Quests tab
2. If not opted in, promo video plays
3. After final video, "I'm In" button appears
4. User taps "I'm In"
5. System calls opt-in API
6. User is now a reward program participant
7. Quests screen shows: opt-in position, associated accounts, quest list

**Data In:** None

**Data to Chain:** None (backend API)

**Data Out:**
- Opt-in position number
- Participation status

**Pending States:** API call only

---

## 13. Manage Accounts

**Intention:** User wants to add, switch between, or edit accounts

**User Flow:**
1. User navigates to Settings → Manage Accounts
2. List shows all accounts grouped by wallet
3. Each account shows: name, checkphrase, address, balance, tags (High Security/Guardian/Entrusted)
4. User taps account to make it active
5. User taps settings icon to view account settings
6. User can tap "Add Account" to create new derived account
7. User can tap "..." menu to: Create new wallet, Import wallet, Add hardware wallet

**Data In:**
- Account selection
- New account name

**Data to Chain:**
- None for switching/editing
- Account derivation is local

**Data Out:**
- Active account changed
- New accounts added to local storage

**Pending States:** None for local operations

---

## 14. Add Hardware Wallet Account (Keystone)

**Intention:** User wants to add a hardware wallet account

**User Flow:**
1. User taps "Add hardware wallet" from accounts screen
2. QR scanner opens to scan Keystone export QR
3. System parses account data from QR
4. User names the account
5. Account added to wallet
6. For transactions: QR code displayed → Sign on device → Scan signature QR back

**Data In:**
- Keystone QR code data
- Account name

**Data to Chain:**
- None for account addition
- Transactions signed on device

**Data Out:**
- Account address from hardware
- Signed transactions

**Pending States:** Same as regular transactions after signature submission

---

## 15. View Transaction History

**Intention:** User wants to see all past transactions

**User Flow:**
1. User taps History tab or scrolls down on home screen
2. Combined list shows:
   - Pending transactions (top, with status indicators)
   - Reversible transfers (with countdown timers)
   - Confirmed transactions (immediate and executed reversible)
3. User can filter by account
4. User can pull-to-refresh
5. User taps transaction for details sheet

**Data In:**
- Account filter selection

**Data to Chain:** None (GraphQL queries to subsquid)

**Data Out:**
- Paginated transaction list
- Transaction details

**Pending States:**
- Background polling every 60 seconds
- Real-time updates for pending/reversible transactions

---

## 16. View Transaction Details

**Intention:** User wants to see full details of a transaction

**User Flow:**
1. User taps transaction in history
2. Details sheet shows:
   - Status icon (sent/received/failed/cancelled)
   - Amount
   - Counterparty checkphrase and address
   - For reversible: remaining time countdown
   - Copy address button
   - View in Explorer link (opens browser)
3. For failed transactions: Retry button available

**Data In:**
- Transaction data from list

**Data to Chain:** None

**Data Out:**
- Formatted transaction details
- Explorer URL: `{explorerEndpoint}/{type}/{hash}`

**Pending States:** Timer updates for reversible transfers

---

## 17. Retry Failed Transaction

**Intention:** User wants to retry a transaction that previously failed

**User Flow:**
1. User views failed transaction details
2. User taps "Retry" button
3. System resubmits same transaction (amount, recipient, reversibility)
4. New pending transaction created
5. Details sheet closes
6. User monitors new transaction status

**Data In:**
- Original transaction data

**Data to Chain:**
- Same extrinsic as original (transfer or reversible transfer)

**Data Out:**
- New transaction hash
- New pending transaction

**Pending States:** Same as original send flow

---

## 18. Configure Notifications

**Intention:** User wants to manage notification preferences

**User Flow:**
1. User navigates to Settings → Notifications
2. User can enable/disable notification types
3. Notifications include:
   - Transaction failed alerts
   - Low balance warnings
   - Reversible transaction reminders
   - Account added confirmations

**Data In:**
- Notification preference toggles

**Data to Chain:** None

**Data Out:**
- Settings stored locally

**Pending States:** None

---

## 19. Share/Invite Others

**Intention:** User wants to invite others to use the app

**User Flow:**
1. User taps "Invite & Share" in Settings
2. System generates share text with referral link
3. System share sheet opens
4. User can send via messaging apps, email, etc.

**Data In:** None

**Data to Chain:** None

**Data Out:**
- Share text with download link and referral info

**Pending States:** None

---

## 20. Reset & Clear Data

**Intention:** User wants to completely reset the app and remove all data

**User Flow:**
1. User taps "Reset & Clear Data" in Settings
2. Confirmation sheet appears with warning
3. User must confirm the action
4. All local data cleared (wallets, accounts, settings)
5. User returned to Welcome Screen

**Data In:**
- Confirmation

**Data to Chain:** None

**Data Out:**
- All local data deleted

**Pending States:** None

---

## Common Pending State Behavior

All transaction submissions follow this pattern:

1. **Optimistic Update:** UI immediately reflects the intended change (balance reduced, transaction in pending list)

2. **Pending State:** Transaction shows status indicators:
   - `created` - Just submitted
   - `inBlock` - Included in a block, awaiting finalization

3. **Polling:** 
   - 10-second intervals for inBlock tracking
   - 5-second aggressive polling for reversible execution detection
   - 60-second background sync for general updates

4. **Confirmation:** Transaction moves from pending to confirmed history

5. **Failure Handling:** 
   - Error message displayed
   - Retry option available
   - Balance reverted to pre-transaction state

---

This covers all the major user flows identified in your codebase. Each flow documents the complete user journey, data requirements, chain interactions, and how pending states are handled asynchronously.