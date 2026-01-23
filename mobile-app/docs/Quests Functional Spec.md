# Quests - Functional Specification

This document defines **what** the Quests feature must do, not **how** to implement it. A designer can use this to create new UI/UX patterns while ensuring all functionality is preserved.

---

## Overview

The Quests feature is a reward/gamification system that incentivizes user engagement through:
- Participation in a reward program
- Social account linking (X/Twitter, Ethereum)
- Referral tracking
- Social media engagement tasks ("raids")
- Activity tracking (sends, reversals, mining)

---

## Core Concepts

### Reward Program
Users must explicitly opt-in to participate. Once opted in, they receive a queue position number that represents their place in the reward distribution.

### Account Associations
Users can link external accounts to their wallet for verification and reward eligibility:
- **X (Twitter) Account** - Verified via posting requirement
- **ETH Address** - For potential cross-chain rewards

### Quests
Time-limited or ongoing tasks that earn points/rewards:
- **Referrals** - Invite others to join
- **King of the Shill (Raids)** - Engage with specific social media content

---

## Functions

### F1. Check Reward Program Status
**Goal:** Determine if user has opted into the reward program

**Inputs:** None (uses authenticated wallet)

**Outputs:**
- Boolean: is participant or not
- If participant: queue position number

**Used to:** Gate access to quests features; show opt-in flow for non-participants

---

### F2. Opt-In to Reward Program
**Goal:** User joins the reward program

**Inputs:**
- Confirmation (user intent)

**Outputs:**
- Success/failure status
- Queue position number (on success)

**Constraints:**
- One-time action (cannot opt out once in)
- Requires wallet to be set up

---

### F3. View Queue Position (removed, not needed)
**Goal:** User sees their position in the reward queue
Note: Let's ditch this. Not needed.
---

### F4. View Account Associations Status
**Goal:** User sees which external accounts are linked

**Inputs:** None

**Outputs:**
- ETH Address: linked/not linked (+ address if linked)
- X Account: linked/not linked (+ username if linked)

**Navigation:** Should allow user to manage associations

---

### F5. Link ETH Address
**Goal:** User associates an Ethereum address with their wallet

**Inputs:**
- ETH address (0x... format)

**Outputs:**
- Success/failure status
- Error message if invalid or already used

**Validation:**
- Must be valid ETH address format

---

### F6. Update ETH Address
**Goal:** User changes their linked ETH address

**Inputs:**
- New ETH address

**Outputs:**
- Success/failure status

**Constraints:**
- Replaces existing association

---

### F7. Remove ETH Address
**Goal:** User unlinks their ETH address

**Inputs:**
- Confirmation

**Outputs:**
- Success/failure status

---

### F8. Link X Account
**Goal:** User verifies ownership of an X (Twitter) account

**Inputs:**
- X handle/username
- Verification post URL (proof of ownership)

**Outputs:**
- Success/failure status
- Error message if verification fails

**Verification Process:**
Verification happens on the backend. UX can focus on just input. 
1. User provides their X handle
2. User must have @QuantusNetwork mentioned in their bio
3. User must post a specific message from that account
4. User provides URL to that post
5. System verifies post exists and matches handle

**Constraints:**
- Post URL must match the provided handle
- Post must contain required verification content

---

### F9. Remove X Account
**Goal:** User unlinks their X account

**Inputs:**
- Confirmation

**Outputs:**
- Success/failure status

---

### F10. View Activity Stats
**Goal:** User sees their engagement statistics

**Inputs:** None

**Outputs:**
- Referral count (people who joined using their code)
- Send count (transactions sent)
- Reversal count (transactions reversed)
- Mining count (blocks mined, if applicable)

**Refresh:** Should support manual refresh

---

### F11. Get My Referral Code
**Goal:** User retrieves their unique referral code

**Inputs:** None

**Outputs:**
- Referral code (human-readable checkphrase format, e.g., "word word word word word")

**Note:** Derived from wallet address, always the same for a given wallet

---

### F12. Share Referral
**Goal:** User shares their referral link with others

**Inputs:** None

**Outputs:**
- Pre-formatted share text including:
  - Referral code
  - Download link
  - Promotional message
- System share sheet triggered

---

### F13. Copy Referral Code
**Goal:** User copies just the referral code

**Inputs:** None

**Outputs:**
- Referral code copied to clipboard
- Confirmation feedback

---

### F14. View Active Raids
**Goal:** User sees available raid quests (King of the Shill)

**Inputs:** None

**Outputs:**
- List state:
  - Active raid available / not available - details are not shown, what to raid appears in the Telegram group
  - There could be an explanation of this?
  - No active raid: show "no active raid" message
  - X not linked: prompt to link X account first

**Constraints:**
- Requires X account to be linked to participate

---

### F15. Submit Raid Entry
**Goal:** User submits proof of raid participation

**Inputs:**
- Reply tweet URL (link to user's reply on raid target)

**Outputs:**
- Success/failure status
- Updated submission list

**Validation:**
- Must be valid X status URL format
- URL must be from user's linked X account

---

### F16. View My Raid Submissions
**Goal:** User sees their submitted raid entries

**Inputs:** None

**Outputs:**
- List of submissions showing:
  - Tweet ID or link
  - Submission status (if applicable)

---

### F17. Remove Raid Submission
**Goal:** User removes a submitted raid entry

**Inputs:**
- Submission ID/tweet ID
- Confirmation

**Outputs:**
- Success/failure status
- Updated submission list

---

### F18. View Submitted Referral Code
**Goal:** User sees if they used someone else's referral code

**Inputs:** None

**Outputs:**
- Referral code used (if any)
- "Not submitted" state if none

**Note:** This is the code the user entered when they joined, not their own code

---

## User States

The quests feature has several distinct user states that affect what is shown:

### State 1: Not Opted In
- Show opt-in promotional content (video/info)
- Show "I'm In" / opt-in action
- No access to quests functionality

### State 2: Opted In, No Associations
- Show queue position
- Show association status (both unlinked)
- Prompt to link accounts
- Show quests list (some may be locked)

### State 3: Opted In, Partial Associations
- Show queue position
- Show association status (partial)
- Show quests list
- Some quests may require specific associations

### State 4: Opted In, Fully Associated
- Show queue position
- Show association status (all linked)
- Full access to all quests

---

## Data Dependencies

| Function | Requires |
|----------|----------|
| F2-F18 | Opted into reward program |
| F8, F14-F17 | X account linked (for raids) |
| F14-F17 | Active raid available (time-limited) |

---

## Error States

Each function should handle:
- Network errors (API unreachable)
- Authentication errors (session expired)
- Validation errors (invalid input)
- Conflict errors (already exists, already submitted)

---

## Refresh Behavior

- **Manual refresh:** Pull-to-refresh on main quests view
- **Auto refresh:** On app resume from background
- **After actions:** Refresh relevant data after submissions/updates

---

## External Links

The feature should support opening external resources:
- "Learn more" links to documentation pages
- X app/website for posting and verification
- Raid target tweets (for context)

---

## Summary of Functions

| ID | Function | Category |
|----|----------|----------|
| F1 | Check Reward Program Status | Core |
| F2 | Opt-In to Reward Program | Core |
| F3 | View Queue Position | Display |
| F4 | View Account Associations Status | Display |
| F5 | Link ETH Address | Association |
| F6 | Update ETH Address | Association |
| F7 | Remove ETH Address | Association |
| F8 | Link X Account | Association |
| F9 | Remove X Account | Association |
| F10 | View Activity Stats | Display |
| F11 | Get My Referral Code | Referral |
| F12 | Share Referral | Referral |
| F13 | Copy Referral Code | Referral |
| F14 | View Active Raids | Raids |
| F15 | Submit Raid Entry | Raids |
| F16 | View My Raid Submissions | Raids |
| F17 | Remove Raid Submission | Raids |
| F18 | View Submitted Referral Code | Referral |

---

## Design Considerations

When redesigning the quests UI, consider:

1. **Progressive disclosure** - Don't overwhelm new users; reveal complexity as they engage
2. **Clear status indicators** - User should always know their current state
3. **Actionable prompts** - Make it clear what steps to take next
4. **Feedback loops** - Immediate feedback on actions (success/error)
5. **Gamification elements** - Make progress feel rewarding
6. **Mobile-first** - Most users will access via mobile app

The current implementation spreads these functions across multiple screens. A redesign could consolidate or reorganize based on user journey analysis.
