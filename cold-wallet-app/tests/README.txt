Quantus Cold Wallet: demo account and test QR codes
===================================================

A demo account for the Quantus Cold Wallet and signing requests addressed to
it, for App Store review and manual testing:

  qr/          every call the wallet can review
  qr/refused/  requests the wallet must refuse: calls it cannot show in full,
               the payloads from past audit reports, an account it does not
               hold
  qr/near/     NEAR transactions, for the ML-DSA-65 account further down

app-review.pdf is the document for Apple: the import steps below and the ten
codes marked * in the list at the end. all-calls.pdf has the same steps and
every code in qr/ itself. The refused and NEAR codes are images only.

The recovery phrase is public. Never send funds to this account.

Recovery phrase (24 words)
--------------------------
 1. dismiss     2. decline     3. gasp        4. pulse
 5. orchard     6. distance    7. isolate     8. inflict
 9. derive     10. tiger      11. glad       12. used
13. humor      14. quarter    15. capital    16. clinic
17. ride       18. hour       19. host       20. purity
21. night      22. steel      23. transfer   24. proud

dismiss decline gasp pulse orchard distance isolate inflict derive tiger glad used humor quarter capital clinic ride hour host purity night steel transfer proud

Account
-------
Signature scheme:  ML-DSA-87
Derivation path:   m/44'/189189'/0'/0'/0'
Address:           qzkiyWnN4MCXeALXfXeNckSK44Mcoyteia7ZE9mh5MUJpSyjg
Checkphrase:       Saddle-Chime-Goose-Fond-Alpha

Import the account
------------------
1. Switch Wi-Fi, cellular and Bluetooth off (Airplane Mode, then check Wi-Fi
   and Bluetooth in Settings). The wallet does not create, import or unlock
   a key while the phone reports any connection. For testing only, the
   "Override for Testing" button on that screen lifts the lock.
2. Tap Import Key, type the 24 words separated by spaces, tap Import Key.
   Leave Advanced untouched: it already selects ML-DSA-87, account 0.
3. Tap Enable Face ID or Use Passcode only, then Go To Wallet.
4. The wallet shows the address and checkphrase above.

Sign a request
--------------
Tap Scan Transaction and point the camera at a code in qr/. A request too
large for one code has one image per part; scan the parts one after the
other. Check the review screen, tap Approve and Sign, and the wallet shows the
signature as a QR code for the hot wallet to scan. Tap Done.

A code in qr/refused/ opens a screen saying why the wallet will not sign it,
with the reason listed below.

The requests are for the Planck test network and are never broadcast.

NEAR account
------------
The codes in qr/near/ are NEAR testnet transactions, which only an ML-DSA-65
key signs. Add one from the same phrase: tap the Q at the top left, then
Manage accounts, Add Account. Open Advanced, choose ML-DSA-65 under Signature
type, check the index reads 0, and tap Create Account.

Signature scheme:  ML-DSA-65
Derivation path:   m/44'/189189'/0'/0'/1'
Address:           qzoT1TSZ9GjQDqJYGdiMWGkZKgQKWiSnWi7pbvxBqjBVMLtUf
Checkphrase:       Marble-Cotton-Float-Donkey-Host

QR codes
--------
qr/ (* = in app-review.pdf)
* 01-balances-transfer_allow_death.png
      SEND 1.5 QTC to qzo5r1kCyoaxTdBTksX2sxhBmCVKioCLQ2hKFNdQXUQ6d3Ymq
      Balances · transfer_allow_death
  02-balances-transfer_keep_alive.png
      SEND 1.5 QTC to qzo5r1kCyoaxTdBTksX2sxhBmCVKioCLQ2hKFNdQXUQ6d3Ymq
      Balances · transfer_keep_alive
* 03-balances-transfer_all.png
      BALANCES TRANSFER ALL
      Balances · transfer_all
  04-balances-burn.png
      BALANCES BURN
      Balances · burn
  05-system-remark.png
      SYSTEM REMARK
      System · remark
  06-system-set_heap_pages.png
      SYSTEM SET HEAP PAGES
      System · set_heap_pages
  07-system-set_code.png
      SYSTEM SET CODE
      System · set_code
  08-system-set_code_without_checks.png
      SYSTEM SET CODE WITHOUT CHECKS
      System · set_code_without_checks
  09-system-set_storage.png
      SYSTEM SET STORAGE
      System · set_storage
  10-system-kill_storage.png
      SYSTEM KILL STORAGE
      System · kill_storage
  11-system-kill_prefix.png
      SYSTEM KILL PREFIX
      System · kill_prefix
  12-system-remark_with_event.png
      SYSTEM REMARK WITH EVENT
      System · remark_with_event
  13-system-authorize_upgrade.png
      SYSTEM AUTHORIZE UPGRADE
      System · authorize_upgrade
  14-system-authorize_upgrade_without_checks.png
      SYSTEM AUTHORIZE UPGRADE WITHOUT CHECKS
      System · authorize_upgrade_without_checks
  15-system-apply_authorized_upgrade.png
      SYSTEM APPLY AUTHORIZED UPGRADE
      System · apply_authorized_upgrade
  16-timestamp-set.png
      TIMESTAMP SET
      Timestamp · set
  17-preimage-note_preimage.png
      PREIMAGE NOTE PREIMAGE
      Preimage · note_preimage → System · remark
  18-preimage-unnote_preimage.png
      PREIMAGE UNNOTE PREIMAGE
      Preimage · unnote_preimage
  19-preimage-request_preimage.png
      PREIMAGE REQUEST PREIMAGE
      Preimage · request_preimage
  20-preimage-unrequest_preimage.png
      PREIMAGE UNREQUEST PREIMAGE
      Preimage · unrequest_preimage
  21-preimage-ensure_updated.png
      PREIMAGE ENSURE UPDATED
      Preimage · ensure_updated
  22-utility-batch_all.png
      UTILITY BATCH ALL
      Utility · batch_all → System · remark
* 23-utility-batch_all-two-transfers.png
      UTILITY BATCH ALL
      Utility · batch_all → 2 × Balances · transfer_allow_death
  24-utility-batch_all-16-transfers-part*.png
      UTILITY BATCH ALL
      Utility · batch_all → 16 × Balances · transfer_allow_death
  25-reversibletransfers-set_high_security.png
      REVERSIBLETRANSFERS SET HIGH SECURITY
      ReversibleTransfers · set_high_security
  26-reversibletransfers-set_high_security-delay-timestamp.png
      REVERSIBLETRANSFERS SET HIGH SECURITY
      ReversibleTransfers · set_high_security
  27-reversibletransfers-cancel.png
      REVERSIBLETRANSFERS CANCEL
      ReversibleTransfers · cancel
  28-reversibletransfers-execute_transfer.png
      REVERSIBLETRANSFERS EXECUTE TRANSFER
      ReversibleTransfers · execute_transfer
* 29-reversibletransfers-schedule_transfer.png
      REVERSIBLE SEND 1.5 QTC to qzo5r1kCyoaxTdBTksX2sxhBmCVKioCLQ2hKFNdQXUQ6d3Ymq
      ReversibleTransfers · schedule_transfer
* 30-reversibletransfers-schedule_transfer_with_delay.png
      REVERSIBLE SEND 1.5 QTC to qzo5r1kCyoaxTdBTksX2sxhBmCVKioCLQ2hKFNdQXUQ6d3Ymq
      ReversibleTransfers · schedule_transfer_with_delay
  31-reversibletransfers-schedule_transfer_with_delay-delay-timestamp.png
      REVERSIBLE SEND 1.5 QTC to qzo5r1kCyoaxTdBTksX2sxhBmCVKioCLQ2hKFNdQXUQ6d3Ymq
      ReversibleTransfers · schedule_transfer_with_delay
  32-reversibletransfers-recover_funds.png
      REVERSIBLETRANSFERS RECOVER FUNDS
      ReversibleTransfers · recover_funds
  33-techcollective-add_member.png
      TECHCOLLECTIVE ADD MEMBER
      TechCollective · add_member
  34-techcollective-promote_member.png
      TECHCOLLECTIVE PROMOTE MEMBER
      TechCollective · promote_member
  35-techcollective-demote_member.png
      TECHCOLLECTIVE DEMOTE MEMBER
      TechCollective · demote_member
  36-techcollective-remove_member.png
      TECHCOLLECTIVE REMOVE MEMBER
      TechCollective · remove_member
* 37-techcollective-vote.png
      TECHCOLLECTIVE VOTE
      TechCollective · vote
  38-techcollective-cleanup_poll.png
      TECHCOLLECTIVE CLEANUP POLL
      TechCollective · cleanup_poll
  39-techcollective-exchange_member.png
      TECHCOLLECTIVE EXCHANGE MEMBER
      TechCollective · exchange_member
  40-techreferenda-submit.png
      TECHREFERENDA SUBMIT
      TechReferenda · submit
  41-techreferenda-submit-proposal_origin-origins.png
      TECHREFERENDA SUBMIT
      TechReferenda · submit
  42-techreferenda-submit-proposal-inline.png
      TECHREFERENDA SUBMIT
      TechReferenda · submit → System · remark
  43-techreferenda-submit-proposal-lookup.png
      TECHREFERENDA SUBMIT
      TechReferenda · submit
  44-techreferenda-submit-enactment_moment-after.png
      TECHREFERENDA SUBMIT
      TechReferenda · submit
  45-techreferenda-place_decision_deposit.png
      TECHREFERENDA PLACE DECISION DEPOSIT
      TechReferenda · place_decision_deposit
  46-techreferenda-refund_decision_deposit.png
      TECHREFERENDA REFUND DECISION DEPOSIT
      TechReferenda · refund_decision_deposit
  47-techreferenda-cancel.png
      TECHREFERENDA CANCEL
      TechReferenda · cancel
  48-techreferenda-kill.png
      TECHREFERENDA KILL
      TechReferenda · kill
  49-techreferenda-nudge_referendum.png
      TECHREFERENDA NUDGE REFERENDUM
      TechReferenda · nudge_referendum
  50-techreferenda-one_fewer_deciding.png
      TECHREFERENDA ONE FEWER DECIDING
      TechReferenda · one_fewer_deciding
  51-techreferenda-refund_submission_deposit.png
      TECHREFERENDA REFUND SUBMISSION DEPOSIT
      TechReferenda · refund_submission_deposit
  52-techreferenda-set_metadata.png
      TECHREFERENDA SET METADATA
      TechReferenda · set_metadata
  53-techreferenda-set_metadata-maybe_hash-some.png
      TECHREFERENDA SET METADATA
      TechReferenda · set_metadata
  54-treasurypallet-set_treasury_account.png
      TREASURYPALLET SET TREASURY ACCOUNT
      TreasuryPallet · set_treasury_account
  55-multisig-create_multisig.png
      MULTISIG CREATE MULTISIG
      Multisig · create_multisig
  56-multisig-propose.png
      MULTISIG PROPOSE
      Multisig · propose → System · remark
  57-multisig-approve.png
      MULTISIG APPROVE
      Multisig · approve → System · remark
  58-multisig-cancel.png
      MULTISIG CANCEL
      Multisig · cancel
  59-multisig-remove_expired.png
      MULTISIG REMOVE EXPIRED
      Multisig · remove_expired
  60-multisig-claim_deposits.png
      MULTISIG CLAIM DEPOSITS
      Multisig · claim_deposits
  61-multisig-execute.png
      MULTISIG EXECUTE
      Multisig · execute → System · remark
* 62-multisig-propose-carrying-a-transfer.png
      MULTISIG PROPOSE 0.9 QTC to qznQKhufTDfU3szAzfgCny7wMhxUN3qjEqneiRUNgC7MjSDyG
      Multisig · propose → Balances · transfer_allow_death
* 63-multisig-approve-carrying-a-transfer.png
      MULTISIG APPROVE 4.2 QTC to qznQKhufTDfU3szAzfgCny7wMhxUN3qjEqneiRUNgC7MjSDyG
      Multisig · approve → Balances · transfer_allow_death
  64-multisig-approve-batch_all-of-16-transfers-part*.png
      MULTISIG APPROVE
      Multisig · approve → Utility · batch_all → 16 × Balances · transfer_allow_death
  65-multisig-propose-batch_all-of-16-transfers-part*.png
      MULTISIG PROPOSE
      Multisig · propose → Utility · batch_all → 16 × Balances · transfer_allow_death
* 66-multisig-execute-carrying-a-transfer.png
      MULTISIG EXECUTE 3 QTC to qznQKhufTDfU3szAzfgCny7wMhxUN3qjEqneiRUNgC7MjSDyG
      Multisig · execute → Balances · transfer_allow_death
  67-wormhole-verify_private_batch.png
      WORMHOLE VERIFY PRIVATE BATCH
      Wormhole · verify_private_batch
  68-wormhole-verify_public_batch.png
      WORMHOLE VERIFY PUBLIC BATCH
      Wormhole · verify_public_batch
* 69-vesting-claim.png
      VESTING CLAIM
      Vesting · claim
  70-vesting-create_schedule.png
      VESTING CREATE SCHEDULE
      Vesting · create_schedule
  71-vesting-end_schedule.png
      VESTING END SCHEDULE
      Vesting · end_schedule
  72-vesting-retarget_schedule.png
      VESTING RETARGET SCHEDULE
      Vesting · retarget_schedule

qr/refused/
  refused/01-multisig-propose-3-one-level-past-the-limit.png
      Multisig · propose × 3 [one level past the limit]
      Refused: call: Cannot parse transaction: call nesting depth 3 exceeds the limit of 2
  refused/02-multisig-propose-10-ten-levels-deep.png
      Multisig · propose × 10 [ten levels deep]
      Refused: call: Cannot parse transaction: call nesting depth 3 exceeds the limit of 2
  refused/03-utility-batch_all-inside-a-batch_all.png
      Utility · batch_all inside a batch_all
      Refused: call: Utility: batch_all cannot be nested inside another batch_all
  refused/04-utility-batch_all-of-multisigs-carrying-batch_alls.png
      Utility · batch_all of multisigs carrying batch_alls
      Refused: call: Utility: batch_all cannot be nested inside another batch_all
  refused/05-multisig-approve-inner-call-padded-with-a-trailing-byte-88483.png
      Multisig · approve, inner call padded with a trailing byte [#88483]
      Refused: call: 1 trailing bytes after nested call
  refused/06-balances-transfer-padded-with-a-trailing-byte-88483.png
      Balances · transfer padded with a trailing byte [#88483]
      Refused: extensions: Invalid Option byte for metadata hash: 17
  refused/07-utility-batch-whose-second-call-cannot-be-decoded-89008.png
      Utility · batch whose second call cannot be decoded [#89008]
      Refused: Pallet 250 call 0 not found
  refused/08-utility-if_else-headlining-1-qtc-over-a-999999-qtc-fallback-88914.png
      Utility · if_else headlining 1 QTC over a 999999 QTC fallback [#88914]
      Refused: Pallet 9 call 6 not found
  refused/09-utility-force_batch-hiding-calls-after-a-failing-one-88730.png
      Utility · force_batch hiding calls after a failing one [#88730]
      Refused: Pallet 9 call 4 not found
  refused/10-utility-cross-schema-payload-hiding-transfer_all-88730.png
      Utility · cross-schema payload hiding transfer_all [#88730]
      Refused: Pallet 9 call 6 not found
  refused/11-balances-transfer-to-an-index-address-88730.png
      Balances · transfer to an Index address [#88730]
      Refused: call: Destination: only a plain account id is accepted, got Index
  refused/12-balances-transfer-to-an-address20-destination-88730.png
      Balances · transfer to an Address20 destination [#88730]
      Refused: call: Destination: only a plain account id is accepted, got Address20
  refused/13-balances-a-transfer-addressed-to-another-account.png
      Balances · a transfer addressed to another account
      Refused: account not in this wallet
  refused/14-balances-transfer_allow_death-dest-raw.png
      Balances · transfer_allow_death [dest=Raw]
      Refused: call: Destination: only a plain account id is accepted, got Raw
  refused/15-balances-transfer_allow_death-dest-address32.png
      Balances · transfer_allow_death [dest=Address32]
      Refused: call: Destination: only a plain account id is accepted, got Address32
  refused/16-balances-transfer_keep_alive-dest-index.png
      Balances · transfer_keep_alive [dest=Index]
      Refused: call: Destination: only a plain account id is accepted, got Index
  refused/17-balances-transfer_keep_alive-dest-raw.png
      Balances · transfer_keep_alive [dest=Raw]
      Refused: call: Destination: only a plain account id is accepted, got Raw
  refused/18-balances-transfer_keep_alive-dest-address32.png
      Balances · transfer_keep_alive [dest=Address32]
      Refused: call: Destination: only a plain account id is accepted, got Address32
  refused/19-balances-transfer_keep_alive-dest-address20.png
      Balances · transfer_keep_alive [dest=Address20]
      Refused: call: Destination: only a plain account id is accepted, got Address20
  refused/20-balances-transfer_all-dest-index.png
      Balances · transfer_all [dest=Index]
      Refused: call: Destination: only a plain account id is accepted, got Index
  refused/21-balances-transfer_all-dest-raw.png
      Balances · transfer_all [dest=Raw]
      Refused: call: Destination: only a plain account id is accepted, got Raw
  refused/22-balances-transfer_all-dest-address32.png
      Balances · transfer_all [dest=Address32]
      Refused: call: Destination: only a plain account id is accepted, got Address32
  refused/23-balances-transfer_all-dest-address20.png
      Balances · transfer_all [dest=Address20]
      Refused: call: Destination: only a plain account id is accepted, got Address20
  refused/24-reversibletransfers-schedule_transfer-dest-index.png
      ReversibleTransfers · schedule_transfer [dest=Index]
      Refused: call: Destination: only a plain account id is accepted, got Index
  refused/25-reversibletransfers-schedule_transfer-dest-raw.png
      ReversibleTransfers · schedule_transfer [dest=Raw]
      Refused: call: Destination: only a plain account id is accepted, got Raw
  refused/26-reversibletransfers-schedule_transfer-dest-address32.png
      ReversibleTransfers · schedule_transfer [dest=Address32]
      Refused: call: Destination: only a plain account id is accepted, got Address32
  refused/27-reversibletransfers-schedule_transfer-dest-address20.png
      ReversibleTransfers · schedule_transfer [dest=Address20]
      Refused: call: Destination: only a plain account id is accepted, got Address20
  refused/28-reversibletransfers-schedule_transfer_with_delay-dest-index.png
      ReversibleTransfers · schedule_transfer_with_delay [dest=Index]
      Refused: call: Destination: only a plain account id is accepted, got Index
  refused/29-reversibletransfers-schedule_transfer_with_delay-dest-raw.png
      ReversibleTransfers · schedule_transfer_with_delay [dest=Raw]
      Refused: call: Destination: only a plain account id is accepted, got Raw
  refused/30-reversibletransfers-schedule_transfer_with_delay-dest-address32.png
      ReversibleTransfers · schedule_transfer_with_delay [dest=Address32]
      Refused: call: Destination: only a plain account id is accepted, got Address32
  refused/31-reversibletransfers-schedule_transfer_with_delay-dest-address20.png
      ReversibleTransfers · schedule_transfer_with_delay [dest=Address20]
      Refused: call: Destination: only a plain account id is accepted, got Address20
  refused/32-techcollective-add_member-who-index.png
      TechCollective · add_member [who=Index]
      Refused: call: Member: only a plain account id is accepted, got Index
  refused/33-techcollective-add_member-who-raw.png
      TechCollective · add_member [who=Raw]
      Refused: call: Member: only a plain account id is accepted, got Raw
  refused/34-techcollective-add_member-who-address32.png
      TechCollective · add_member [who=Address32]
      Refused: call: Member: only a plain account id is accepted, got Address32
  refused/35-techcollective-add_member-who-address20.png
      TechCollective · add_member [who=Address20]
      Refused: call: Member: only a plain account id is accepted, got Address20
  refused/36-techcollective-promote_member-who-index.png
      TechCollective · promote_member [who=Index]
      Refused: call: Member: only a plain account id is accepted, got Index
  refused/37-techcollective-promote_member-who-raw.png
      TechCollective · promote_member [who=Raw]
      Refused: call: Member: only a plain account id is accepted, got Raw
  refused/38-techcollective-promote_member-who-address32.png
      TechCollective · promote_member [who=Address32]
      Refused: call: Member: only a plain account id is accepted, got Address32
  refused/39-techcollective-promote_member-who-address20.png
      TechCollective · promote_member [who=Address20]
      Refused: call: Member: only a plain account id is accepted, got Address20
  refused/40-techcollective-demote_member-who-index.png
      TechCollective · demote_member [who=Index]
      Refused: call: Member: only a plain account id is accepted, got Index
  refused/41-techcollective-demote_member-who-raw.png
      TechCollective · demote_member [who=Raw]
      Refused: call: Member: only a plain account id is accepted, got Raw
  refused/42-techcollective-demote_member-who-address32.png
      TechCollective · demote_member [who=Address32]
      Refused: call: Member: only a plain account id is accepted, got Address32
  refused/43-techcollective-demote_member-who-address20.png
      TechCollective · demote_member [who=Address20]
      Refused: call: Member: only a plain account id is accepted, got Address20
  refused/44-techcollective-remove_member-who-index.png
      TechCollective · remove_member [who=Index]
      Refused: call: Member: only a plain account id is accepted, got Index
  refused/45-techcollective-remove_member-who-raw.png
      TechCollective · remove_member [who=Raw]
      Refused: call: Member: only a plain account id is accepted, got Raw
  refused/46-techcollective-remove_member-who-address32.png
      TechCollective · remove_member [who=Address32]
      Refused: call: Member: only a plain account id is accepted, got Address32
  refused/47-techcollective-remove_member-who-address20.png
      TechCollective · remove_member [who=Address20]
      Refused: call: Member: only a plain account id is accepted, got Address20
  refused/48-techcollective-exchange_member-who-index.png
      TechCollective · exchange_member [who=Index]
      Refused: call: Existing member: only a plain account id is accepted, got Index
  refused/49-techcollective-exchange_member-who-raw.png
      TechCollective · exchange_member [who=Raw]
      Refused: call: Existing member: only a plain account id is accepted, got Raw
  refused/50-techcollective-exchange_member-who-address32.png
      TechCollective · exchange_member [who=Address32]
      Refused: call: Existing member: only a plain account id is accepted, got Address32
  refused/51-techcollective-exchange_member-who-address20.png
      TechCollective · exchange_member [who=Address20]
      Refused: call: Existing member: only a plain account id is accepted, got Address20
  refused/52-techcollective-exchange_member-new_who-index.png
      TechCollective · exchange_member [new_who=Index]
      Refused: call: Replacement member: only a plain account id is accepted, got Index
  refused/53-techcollective-exchange_member-new_who-raw.png
      TechCollective · exchange_member [new_who=Raw]
      Refused: call: Replacement member: only a plain account id is accepted, got Raw
  refused/54-techcollective-exchange_member-new_who-address32.png
      TechCollective · exchange_member [new_who=Address32]
      Refused: call: Replacement member: only a plain account id is accepted, got Address32
  refused/55-techcollective-exchange_member-new_who-address20.png
      TechCollective · exchange_member [new_who=Address20]
      Refused: call: Replacement member: only a plain account id is accepted, got Address20

qr/near/
  near/01-send-1-5-near-part*.png
      send 1.5 NEAR
      Signs with the ML-DSA-65 account
  near/02-ft_transfer-on-a-token-contract-part*.png
      ft_transfer on a token contract
      Signs with the ML-DSA-65 account
  near/03-swap-ft_transfer_call-then-storage_deposit-two-actions-part*.png
      swap: ft_transfer_call then storage_deposit [two actions]
      Signs with the ML-DSA-65 account
  near/04-add-a-full-access-key-dangerous-part*.png
      add a full access key [dangerous]
      Signs with the ML-DSA-65 account
  near/05-add-a-function-call-key-limited-to-one-contract-part*.png
      add a function call key limited to one contract
      Signs with the ML-DSA-65 account
  near/06-delete-the-account-balance-to-bob-dangerous-part*.png
      delete the account, balance to bob [dangerous]
      Signs with the ML-DSA-65 account
  near/07-mainnet-label-on-testnet-account-names-mismatch-part*.png
      mainnet label on testnet account names [mismatch]
      Signs with the ML-DSA-65 account
  near/08-signed-by-an-ed25519-key-refused.png
      signed by an ed25519 key [refused]
      Refused: not a Quantus key
  near/09-signed-by-an-ml-dsa-65-key-this-wallet-does-not-hold-refused-part*.png
      signed by an ML-DSA-65 key this wallet does not hold [refused]
      Refused: key not in this wallet

Regenerate
----------
Build the SDK's Rust library once (quantus_sdk/test/build_library.sh), then
run cold-wallet-app/tests/generate.sh. The calls and the phrase are set in
generate_review_qr.dart.
