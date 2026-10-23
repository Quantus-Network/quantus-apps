Quantus Cold Wallet: demo account and test QR codes
===================================================

A demo account for the Quantus Cold Wallet and signing requests addressed to
it, for App Store review and manual testing. app-review.pdf is the document
for Apple: the import steps below and every QR code in qr/.

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
01-balances-transfer_allow_death.png
    SEND 1.5 QTC to qzo5r1kCyoaxTdBTksX2sxhBmCVKioCLQ2hKFNdQXUQ6d3Ymq
    Balances · transfer_allow_death
02-balances-transfer_all.png
    BALANCES TRANSFER ALL
    Balances · transfer_all
03-reversibletransfers-schedule_transfer.png
    REVERSIBLE SEND 1.5 QTC to qzo5r1kCyoaxTdBTksX2sxhBmCVKioCLQ2hKFNdQXUQ6d3Ymq
    ReversibleTransfers · schedule_transfer
04-reversibletransfers-schedule_transfer_with_delay.png
    REVERSIBLE SEND 1.5 QTC to qzo5r1kCyoaxTdBTksX2sxhBmCVKioCLQ2hKFNdQXUQ6d3Ymq
    ReversibleTransfers · schedule_transfer_with_delay
05-utility-batch_all-two-transfers.png
    UTILITY BATCH ALL
    Utility · batch_all → Balances · transfer_allow_death → Balances · transfer_allow_death
06-multisig-propose-carrying-a-transfer.png
    MULTISIG PROPOSE 0.9 QTC to qznQKhufTDfU3szAzfgCny7wMhxUN3qjEqneiRUNgC7MjSDyG
    Multisig · propose → Balances · transfer_allow_death
07-multisig-approve-carrying-a-transfer.png
    MULTISIG APPROVE 4.2 QTC to qznQKhufTDfU3szAzfgCny7wMhxUN3qjEqneiRUNgC7MjSDyG
    Multisig · approve → Balances · transfer_allow_death
08-multisig-execute-carrying-a-transfer.png
    MULTISIG EXECUTE 3 QTC to qznQKhufTDfU3szAzfgCny7wMhxUN3qjEqneiRUNgC7MjSDyG
    Multisig · execute → Balances · transfer_allow_death
09-techcollective-vote.png
    TECHCOLLECTIVE VOTE
    TechCollective · vote
10-vesting-claim.png
    VESTING CLAIM
    Vesting · claim

Regenerate
----------
Build the SDK's Rust library once (quantus_sdk/test/build_library.sh), then
run cold-wallet-app/tests/generate.sh. The calls and the phrase are set in
generate_review_qr.dart.
