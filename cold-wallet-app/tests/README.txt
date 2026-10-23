Quantus Cold Wallet: demo account and test QR codes
===================================================

A demo account for the Quantus Cold Wallet and a signing request addressed to
it for every call the wallet can review, for App Store review and manual
testing. app-review.pdf is the document for Apple: the import steps below and
the ten codes marked * in the list at the end. all-calls.pdf has the same
steps and every code in qr/.

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

The requests are for the Planck test network and are never broadcast.

QR codes
--------
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

Regenerate
----------
Build the SDK's Rust library once (quantus_sdk/test/build_library.sh), then
run cold-wallet-app/tests/generate.sh. The calls and the phrase are set in
generate_review_qr.dart.
