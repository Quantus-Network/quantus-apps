// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get walletInitErrorTitle => 'Wallet Bermasalah';

  @override
  String get walletInitErrorMessage => 'Gagal mencari secret phrase. Coba pulihkan wallet anda.';

  @override
  String get walletInitErrorButtonLabel => 'OK';

  @override
  String get authUseDeviceBiometricsToUnlock => 'Gunakan biometrik untuk mengakses wallet';

  @override
  String get authAuthenticating => 'Mengotentikasi...';

  @override
  String get authUnlockWallet => 'Buka Wallet';

  @override
  String get authAuthorizationRequired => 'Otorisasi \n Diperlukan';

  @override
  String get welcomeTagline => 'Uang Terenkripsi Aman Kuantum';

  @override
  String get welcomeCreateNewWallet => 'Buat Wallet Baru';

  @override
  String get welcomeImportWallet => 'Impor Wallet';

  @override
  String get createWalletCautionHeadline => 'Jaga Kerahasiaan Recovery Phrase Anda';

  @override
  String get createWalletCautionBullet1 =>
      'Jika Anda kehilangan perangkat ini, recovery phrase adalah satu-satunya cara kembali';

  @override
  String get createWalletCautionBullet2 =>
      'Siapa pun yang mendapatkannya akan memiliki kendali penuh atas dana Anda, secara permanen';

  @override
  String get createWalletCautionBullet3 => 'Tuliskan dan simpan di tempat yang aman. Jangan simpan secara digital';

  @override
  String createWalletRecoveryPhraseSaveError(String error) {
    return 'Gagal menyimpan wallet: $error';
  }

  @override
  String get recoveryPhraseBodyInstructions =>
      'Tuliskan kata-kata ini secara berurutan dan simpan di tempat yang hanya Anda yang bisa akses. Jangan screenshot atau salin ke aplikasi catatan.';

  @override
  String get recoveryPhraseBodyCopy => 'Salin';

  @override
  String get recoveryPhraseBodyTapToReveal => 'Ketuk untuk menampilkan';

  @override
  String get recoveryPhraseBodyTapToHide => 'Ketuk untuk menyembunyikan';

  @override
  String get recoveryPhraseBodyCopiedMessage => 'Recovery phrase disalin ke clipboard';

  @override
  String get accountReadyAccountCreated => 'Akun Dibuat';

  @override
  String get accountReadyWalletCreated => 'Wallet Dibuat';

  @override
  String get accountReadyWalletImported => 'Wallet Diimpor';

  @override
  String get accountReadyDone => 'Selesai';

  @override
  String get accountReadyTwoAccountsCreated => 'Dua akun telah dibuat untuk Anda.';

  @override
  String get accountReadyMainAccountDescription => 'Akun utama Anda. Cepat, terlihat di chain.';

  @override
  String get accountReadyEncryptedAccountDescription => 'Untuk transaksi privat. Tershield, lebih lambat.';

  @override
  String get accountReadyGoToWallet => 'Buka Wallet';

  @override
  String get importWalletAppBarTitle => 'Impor Wallet';

  @override
  String get importWalletDescription => 'Pulihkan wallet yang ada dengan recovery phrase 12 atau 24 kata Anda';

  @override
  String get importWalletHint => 'Ketik atau tempel recovery phrase Anda. Pisahkan kata dengan spasi.';

  @override
  String get importWalletButton => 'Impor';

  @override
  String get importWalletValidationError => 'Recovery phrase harus 12 atau 24 kata';

  @override
  String homeError(String error) {
    return 'Gagal: $error';
  }

  @override
  String get homeNoActiveAccount => 'Tidak ada akun aktif';

  @override
  String get homeErrorLoadingBalance => 'Gagal memuat saldo';

  @override
  String get homeBackupReminder => 'Cadangkan recovery phrase Anda';

  @override
  String get networkStatusOfflineBanner => 'Offline · menampilkan saldo terakhir';

  @override
  String get homeReceive => 'Terima';

  @override
  String get homeSend => 'Kirim';

  @override
  String get homeSwap => 'Tukar';

  @override
  String get homeActivityTitle => 'Aktivitas';

  @override
  String get homeActivityViewAll => 'Lihat Semua';

  @override
  String get homeActivityErrorLoading => 'Gagal memuat transaksi';

  @override
  String get homeActivityRetry => 'Coba Lagi';

  @override
  String get homeActivityEmptyTitle => 'Belum Ada Transaksi';

  @override
  String homeActivityEmptyMessage(String tokenSymbol) {
    return 'Aktivitas Anda akan muncul di sini setelah Anda mengirim atau menerima $tokenSymbol.';
  }

  @override
  String get accountsSheetTitle => 'Akun';

  @override
  String get accountsSheetFailedLoadAccounts => 'Gagal memuat akun.';

  @override
  String get accountsSheetFailedLoadActiveAccount => 'Gagal memuat akun aktif.';

  @override
  String get accountsSheetNoAccountsFound => 'Tidak ada akun ditemukan.';

  @override
  String get accountsSheetAddAccount => 'Tambah Akun';

  @override
  String get accountsSheetBalanceUnavailable => 'Saldo tidak tersedia';

  @override
  String accountsSheetBalance(String balance, String symbol) {
    return '$balance $symbol';
  }

  @override
  String accountsSheetWallet(int number) {
    return 'Wallet $number';
  }

  @override
  String accountsSheetKeystoneWallet(int number) {
    String _temp0 = intl.Intl.pluralLogic(
      number,
      locale: localeName,
      other: 'Wallet Perangkat Keras Keystone $number',
      one: 'Wallet Perangkat Keras Keystone',
    );
    return '$_temp0';
  }

  @override
  String get accountsScreenActiveWallet => 'Wallet Aktif';

  @override
  String accountsScreenAccountCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Akun', one: '1 Akun');
    return '$_temp0';
  }

  @override
  String get walletNameTitle => 'Nama Wallet';

  @override
  String get walletNameSubtitle =>
      'Memberi nama wallet memudahkan Anda membedakan akun-akunnya. Setiap wallet memiliki akun terenkripsi sendiri.';

  @override
  String get walletNameHint => 'Masukkan nama untuk wallet Anda';

  @override
  String get addAccountMenuTitle => 'Tambah Akun';

  @override
  String get addAccountMenuCreateTitle => 'Tambah Akun Transparan';

  @override
  String get addAccountMenuCreateSubtitle => 'Tambahkan akun publik lainnya';

  @override
  String get addAccountMenuMoreTitle => 'Lanjutan';

  @override
  String get addAccountMenuImportKeystoneTitle => 'Tambah Wallet Keystone';

  @override
  String get addAccountMenuImportKeystoneSubtitle => 'Penandatanganan air-gap melalui kode QR';

  @override
  String get addAccountMenuImportTitle => 'Impor Akun';

  @override
  String get addAccountMenuImportSubtitle => 'Pulihkan dari recovery phrase';

  @override
  String get addAccountMenuMultisigTitle => 'Buat Akun Multisig';

  @override
  String get addAccountMenuMultisigSubtitle => 'Siapkan alamat bersama dengan beberapa penandatangan';

  @override
  String get addAccountMenuDiscoverMultisigTitle => 'Tambah Akun Multisig';

  @override
  String get addAccountMenuDiscoverMultisigSubtitle => 'Cari multisig di mana akun Anda adalah penandatangan';

  @override
  String get multisigTag => 'MULTISIG';

  @override
  String get multisigProposeTitle => 'Ajukan';

  @override
  String get multisigAddTitle => 'Buat Multisig';

  @override
  String get multisigDiscoverTitle => 'Temukan Multisig';

  @override
  String get multisigCreateSubtitle =>
      'Berikan nama multisig yang mudah Anda kenali. Anda bisa mengubahnya kapan saja.';

  @override
  String get multisigCreateButton => 'Buat';

  @override
  String get multisigCreateCreatingButton => 'Membuat';

  @override
  String multisigCreateDefaultName(int number) {
    return 'Multisig $number';
  }

  @override
  String get multisigCreateErrorCouldNotCreate => 'Gagal membuat multisig.';

  @override
  String get multisigCreateReadyToast => 'Multisig ditambahkan ke akun Anda.';

  @override
  String get multisigCreateAlreadyExists => 'Multisig dengan alamat ini sudah ada on-chain.';

  @override
  String get multisigCreateInsufficientBalance => 'Saldo tidak cukup untuk biaya pembuatan multisig.';

  @override
  String get multisigCreateTimeoutToast =>
      'Pembuatan multisig membutuhkan waktu lebih lama. Periksa chain atau coba lagi.';

  @override
  String get multisigCreateAuthReason => 'Autentikasi untuk membuat multisig ini';

  @override
  String get multisigCreateSignersLabel => 'PENANDATANGAN';

  @override
  String get multisigCreateSignersSubtitle => 'Tambahkan setidaknya satu penandatangan selain diri Anda.';

  @override
  String get multisigCreateAddSignerHint => 'Alamat penandatangan';

  @override
  String get multisigCreateAddSignerButton => 'Tambah Penandatangan';

  @override
  String get multisigCreateDuplicateSigner => 'Penandatangan ini sudah ada dalam daftar.';

  @override
  String get multisigCreateInvalidSigner => 'Masukkan alamat penandatangan yang valid.';

  @override
  String get multisigCreateThresholdLabel => 'AMBANG BATAS';

  @override
  String multisigCreateThresholdValue(int count, int total) {
    return '$count dari $total';
  }

  @override
  String multisigCreateKeystoneAction(int count, int total) {
    return 'Buat multisig $count dari $total';
  }

  @override
  String get multisigCreatePredictedAddressLabel => 'ALAMAT MULTISIG';

  @override
  String get multisigCreatePredictedAddressPlaceholder => 'Tambahkan penandatangan untuk melihat alamat';

  @override
  String get multisigDone => 'Selesai';

  @override
  String get multisigAddDiscoveredTitle => 'Ditemukan untuk Anda';

  @override
  String get multisigAddDiscoveredSubtitle => 'Multisig di chain di mana salah satu akun Anda adalah penandatangan';

  @override
  String get multisigAddButton => 'Tambah';

  @override
  String get multisigAddedButton => 'Ditambahkan';

  @override
  String get multisigAddNoneFound => 'Tidak ada multisig ditemukan.';

  @override
  String multisigAddDiscoverFailed(String error) {
    return 'Tidak dapat menemukan multisig: $error';
  }

  @override
  String multisigAddFailed(String error) {
    return 'Tidak dapat menambahkan multisig: $error';
  }

  @override
  String get multisigOpenProposals => 'Proposal Terbuka';

  @override
  String get multisigPastProposals => 'Proposal Sebelumnya';

  @override
  String get multisigNoOpenProposals => 'Tidak ada proposal terbuka.';

  @override
  String get multisigNoPastProposals => 'Tidak ada proposal sebelumnya.';

  @override
  String multisigLoadFailed(String error) {
    return 'Gagal memuat: $error';
  }

  @override
  String multisigProposalToAddress(String address) {
    return 'ke $address';
  }

  @override
  String get multisigProposalCallLoading => 'Membaca usulan dari rantai…';

  @override
  String get multisigProposalCallUnavailable =>
      'Tidak dapat membaca usulan ini dari rantai, jadi tidak ada yang bisa disetujui. Coba lagi setelah Anda kembali online.';

  @override
  String get multisigProposalInvalid => 'Proposal tidak valid';

  @override
  String get multisigStatusApproved => 'DITANDATANGANI';

  @override
  String get multisigStatusProposed => 'DIAJUKAN';

  @override
  String get multisigStatusExpired => 'KEDALUWARSA';

  @override
  String get multisigStatusCancelled => 'DIBATALKAN';

  @override
  String get multisigProposeSelectRecipientTo => 'Transfer ke';

  @override
  String multisigProposeSearchHint(String symbol) {
    return 'Masukkan Alamat $symbol';
  }

  @override
  String get multisigProposeAmountToLabel => 'TRANSFER KE';

  @override
  String get multisigProposeDepositLabel => 'Deposit:';

  @override
  String get multisigProposeCreationFeeLabel => 'Biaya Proposal:';

  @override
  String get multisigProposeDepositRefundableNote => 'dapat dikembalikan';

  @override
  String get multisigProposeMemberTotalLabel => 'TOTAL DARI AKUN ANDA';

  @override
  String get multisigProposeFeeLabel => 'Biaya Proposal:';

  @override
  String get multisigProposeFeeFetchFailed => 'Tidak dapat memperkirakan biaya';

  @override
  String get multisigProposeFeePayerBalanceLabel => 'Saldo Anda:';

  @override
  String get multisigProposeFeePayerInsufficient => 'Saldo Tidak Cukup untuk Biaya';

  @override
  String get multisigProposeProposerLabel => 'PENGUSUL';

  @override
  String get multisigProposeReviewButton => 'Tinjau transfer';

  @override
  String get multisigProposeReviewProposing => 'TRANSFER YANG DIAJUKAN';

  @override
  String multisigProposeReviewFromName(String name) {
    return 'dari $name';
  }

  @override
  String get multisigProposeThresholdLabel => 'AMBANG';

  @override
  String get multisigProposeExpiresLabel => 'KEDALUWARSA';

  @override
  String multisigExpiresBlockOnly(int block) {
    return 'Blok $block';
  }

  @override
  String get multisigProposeFeeRowLabel => 'BIAYA PROPOSAL';

  @override
  String get multisigProposeCreateButton => 'Kirim proposal';

  @override
  String get multisigProposeAuthReason => 'Autentikasi untuk mengajukan transaksi';

  @override
  String get multisigProposeAuthRequired => 'Autentikasi diperlukan';

  @override
  String get multisigProposeSubmitFailed => 'Gagal membuat proposal';

  @override
  String get multisigProposeTimeoutToast =>
      'Konfirmasi proposal membutuhkan waktu lebih lama. Periksa chain atau coba lagi.';

  @override
  String get multisigProposeDoneHeadline => 'Proposal transfer terkirim';

  @override
  String get multisigProposeDoneSubline => 'Co-signer harus menyetujui sebelum transfer dapat dieksekusi.';

  @override
  String multisigProposeDoneToChecksum(String checksum) {
    return 'ke $checksum';
  }

  @override
  String multisigSignaturesCount(int current, int threshold) {
    return 'Tanda tangan: $current/$threshold';
  }

  @override
  String get multisigProposalTitle => 'Proposal';

  @override
  String multisigProposalLoadFailed(String error) {
    return 'Gagal: $error';
  }

  @override
  String get multisigProposalNotFound => 'Proposal tidak ditemukan.';

  @override
  String get multisigProposalSignButton => 'Tanda Tangan';

  @override
  String get multisigProposalSigningSoonNote => 'Penandatanganan akan segera tersedia.';

  @override
  String get multisigProposalApprovingLabel => 'Menyetujui…';

  @override
  String get multisigProposalApprovingNote => 'Persetujuan Anda sedang dikonfirmasi di chain.';

  @override
  String get multisigApproveUnavailableNote => 'Proposal ini tidak dapat disetujui lagi.';

  @override
  String get activityTxApproving => 'Menyetujui…';

  @override
  String get activityTxCancelling => 'Membatalkan…';

  @override
  String get multisigApprovalTimeoutToast =>
      'Konfirmasi persetujuan membutuhkan waktu lebih lama. Periksa chain atau coba lagi.';

  @override
  String get multisigProposalAlreadySignedNote => 'Anda sudah menandatangani proposal ini.';

  @override
  String get multisigProposalAlreadyExecutedNote => 'Proposal ini sudah dieksekusi.';

  @override
  String get multisigProposalAlreadyCancelledNote => 'Proposal ini sudah dibatalkan.';

  @override
  String get multisigProposalProposerLabel => 'PENGAJU';

  @override
  String get multisigProposalStatusLabel => 'STATUS';

  @override
  String get multisigProposalDepositLabel => 'DEPOSIT';

  @override
  String get multisigStatusActive => 'AKTIF';

  @override
  String get multisigStatusExecuted => 'DIEKSEKUSI';

  @override
  String get multisigStatusRemoved => 'DIHAPUS';

  @override
  String get multisigStatusUnknown => 'TIDAK DIKENAL';

  @override
  String get activityTxProposal => 'Proposal';

  @override
  String get activityTxProposing => 'Mengajukan';

  @override
  String get activityTxProposalCreated => 'Proposal dibuat';

  @override
  String get activityTxProposalApproved => 'Proposal disetujui';

  @override
  String get activityTxProposalExecuted => 'Proposal dieksekusi';

  @override
  String get activityTxProposalCancelled => 'Proposal dibatalkan';

  @override
  String get multisigApproveButton => 'Setujui';

  @override
  String get multisigAlreadyApproved => 'Sudah Ditandatangani';

  @override
  String get multisigSignerPickerTitle => 'Pilih akun';

  @override
  String get multisigSignerPickerBody =>
      'Beberapa akun di perangkat ini dapat menandatangani. Pilih akun mana yang akan digunakan untuk menyetujui.';

  @override
  String get multisigCancelProposalButton => 'Batalkan Proposal';

  @override
  String get multisigProposalExpiresLabel => 'KEDALUWARSA';

  @override
  String get multisigProposalAtLabel => 'PADA';

  @override
  String get multisigProposalThresholdLabel => 'AMBANG';

  @override
  String get multisigProposalApprovalsLabel => 'PERSETUJUAN';

  @override
  String get multisigProposalFeeRowLabel => 'BIAYA PROPOSAL';

  @override
  String get multisigProposalSignersLabel => 'PENANDATANGAN';

  @override
  String get multisigYouLabel => 'ANDA';

  @override
  String get multisigSignerCreatorLabel => 'PEMBUAT';

  @override
  String get multisigAccountMenuDetails => 'Detail multisig';

  @override
  String get multisigAccountMenuDetailsTitle => 'Detail multisig';

  @override
  String get multisigAccountMenuDetailsThresholdHint =>
      'Jumlah persetujuan penandatangan yang diperlukan untuk mengeksekusi proposal.';

  @override
  String multisigThresholdOf(int count, int total) {
    return '$count dari $total';
  }

  @override
  String multisigApprovalsOf(int count, int threshold) {
    return '$count dari $threshold';
  }

  @override
  String get multisigApproveConfirmTitle => 'Apakah Anda yakin?';

  @override
  String get multisigApproveConfirmBody => 'Anda akan menyetujui transfer sebesar';

  @override
  String multisigApproveConfirmTo(String address) {
    return 'ke $address';
  }

  @override
  String get multisigApproveConfirmYes => 'Ya, Setujui';

  @override
  String get multisigApproveConfirmNo => 'Tidak, Kembali';

  @override
  String get multisigApproveAuthReason => 'Autentikasi untuk menyetujui';

  @override
  String get multisigAuthRequired => 'Autentikasi diperlukan';

  @override
  String get multisigApproveFailed => 'Gagal menyetujui';

  @override
  String get multisigExecuteButton => 'Eksekusi';

  @override
  String get multisigExecuteConfirmTitle => 'Apakah Anda yakin?';

  @override
  String get multisigExecuteConfirmBody => 'Anda akan mengeksekusi transfer sebesar';

  @override
  String get multisigExecuteConfirmYes => 'Ya, Eksekusi';

  @override
  String get multisigExecuteAuthReason => 'Autentikasi untuk mengeksekusi';

  @override
  String get multisigExecuteFailed => 'Gagal mengeksekusi';

  @override
  String get multisigExecuteUnavailableNote => 'Proposal ini tidak dapat dieksekusi lagi.';

  @override
  String get multisigProposalExecutingLabel => 'Mengeksekusi…';

  @override
  String get multisigProposalExecutingNote => 'Eksekusi Anda sedang dikonfirmasi di chain.';

  @override
  String get activityTxExecuting => 'Mengeksekusi…';

  @override
  String get multisigExecutionTimeoutToast =>
      'Konfirmasi eksekusi membutuhkan waktu lebih lama. Periksa chain atau coba lagi.';

  @override
  String get multisigExecutedByOtherToast => 'Proposal telah dieksekusi oleh penandatangan lain.';

  @override
  String get multisigFeeEstimateUnavailable => 'Estimasi biaya jaringan tidak tersedia.';

  @override
  String get multisigCancelConfirmTitle => 'Batalkan Proposal?';

  @override
  String get multisigCancelConfirmBody =>
      'Pembatalan mengembalikan deposit proposal Anda. Penandatangan lain tidak dapat lagi menyetujui.';

  @override
  String get multisigCancelConfirmYes => 'Ya, Batalkan Proposal';

  @override
  String get multisigCancelConfirmKeep => 'Pertahankan Proposal';

  @override
  String get multisigCancelAuthReason => 'Autentikasi untuk membatalkan';

  @override
  String get multisigCancelFailed => 'Gagal membatalkan';

  @override
  String get multisigProposalCancellingLabel => 'Membatalkan…';

  @override
  String get multisigProposalCancellingNote => 'Pembatalan Anda sedang dikonfirmasi di chain.';

  @override
  String get multisigCancelTimeoutToast =>
      'Konfirmasi pembatalan membutuhkan waktu lebih lama. Periksa chain atau coba lagi.';

  @override
  String get multisigApproveTitle => 'Setujui';

  @override
  String get multisigApproveDoneExecuted => 'Proposal dieksekusi';

  @override
  String get multisigApproveDoneRecorded => 'Persetujuan dicatat';

  @override
  String get multisigApproveDoneExecutedSubline => 'Ambang tercapai — transfer dikirim.';

  @override
  String get multisigApproveDoneRecordedSubline => 'Menunggu co-signer lainnya.';

  @override
  String get createAccountAppBarTitle => 'Nama Akun';

  @override
  String get createAccountSubtitle => 'Berikan nama yang mudah Anda kenali. Anda bisa mengubahnya kapan saja.';

  @override
  String get createAccountButton => 'Buat';

  @override
  String get createAccountErrorCouldNotAdd => 'Gagal menambahkan akun.';

  @override
  String get createAccountEncryptedDefaultName => 'Akun Terenkripsi';

  @override
  String createAccountDefaultName(int number) {
    return 'Akun $number';
  }

  @override
  String get editAccountAppBarTitle => 'Nama Akun';

  @override
  String get editAccountDone => 'Selesai';

  @override
  String get editAccountNameEmpty => 'Nama akun tidak boleh kosong';

  @override
  String get editAccountRenameFailed => 'Gagal mengganti nama akun.';

  @override
  String get accountMenuTitle => 'Akun';

  @override
  String get accountMenuAccountName => 'Nama Akun';

  @override
  String get accountMenuAddressDetails => 'Detail Alamat';

  @override
  String get accountMenuInnerHash => 'Inner Hash';

  @override
  String get accountMenuShowRecoveryPhrase => 'Tampilkan Recovery Phrase';

  @override
  String get accountMenuNotFound => 'Akun tidak ditemukan';

  @override
  String get accountMenuDone => 'Selesai';

  @override
  String get accountMenuDisconnect => 'Putuskan';

  @override
  String get accountMenuDisconnectHardwareTitle => 'Putuskan dompet perangkat keras?';

  @override
  String accountMenuDisconnectHardwareMessage(String name) {
    return 'Ini menghentikan pelacakan \"$name\" di perangkat ini. Dompet perangkat keras Anda tetap menyimpan akun, jadi Anda dapat menghubungkannya kembali kapan saja.';
  }

  @override
  String get accountMenuDisconnectMultisigTitle => 'Putuskan multisig?';

  @override
  String accountMenuDisconnectMultisigMessage(String name) {
    return 'Ini menghentikan pelacakan \"$name\" di perangkat ini. Multisig tetap ada di on-chain, jadi Anda dapat menambahkannya kembali kapan saja.';
  }

  @override
  String get accountMenuDisconnectError => 'Tidak dapat memutuskan. Silakan coba lagi.';

  @override
  String get accountMenuDisconnectAccountTitle => 'Putuskan akun?';

  @override
  String accountMenuDisconnectAccountMessage(String name) {
    return 'Ini menghentikan pelacakan \"$name\" di perangkat ini. Frasa pemulihan Anda tetap tersimpan, jadi Anda dapat memulihkannya nanti.';
  }

  @override
  String accountMenuDisconnectWalletTitle(int number) {
    return 'Putuskan Dompet $number?';
  }

  @override
  String accountMenuDisconnectWalletMessage(String name, int number) {
    return '\"$name\" adalah akun terakhir di Dompet $number. Memutuskannya akan menghapus seluruh dompet dari perangkat ini.';
  }

  @override
  String get accountMenuDisconnectWalletConfirm => 'Putuskan Dompet';

  @override
  String get accountMenuDeleteWalletTitle => 'Apakah Anda yakin?';

  @override
  String accountMenuDeleteWalletMessage(int number) {
    return 'Frasa pemulihan Dompet $number akan dihapus permanen dari perangkat ini. Pastikan sudah dicadangkan — ini tidak dapat dibatalkan.';
  }

  @override
  String get accountMenuDeleteWalletConfirm => 'Hapus Dompet';

  @override
  String get accountDetailsTitle => 'Detail Alamat';

  @override
  String get innerHashTitle => 'Inner Hash';

  @override
  String get innerHashLabel => 'INNER HASH';

  @override
  String get innerHashCopied => 'Inner hash disalin';

  @override
  String get innerHashLoadError => 'Gagal memuat inner hash';

  @override
  String get addKeystoneAppBarTitle => 'Add Keystone Wallet';

  @override
  String get addKeystoneIntroTitle => 'Keystone Hardware Wallet';

  @override
  String get addKeystoneIntroSubtitle =>
      'Air-gapped signing for QTC. Keys stay on the device, signing happens over QR.';

  @override
  String get addKeystoneConnectButton => 'Connect Hardware Wallet';

  @override
  String get addKeystoneGetOneLink => 'Don\'t have one? Get a Keystone ↗';

  @override
  String get addKeystoneConnectTitle => 'Connect Hardware Wallet';

  @override
  String get addKeystoneConnectSubtitle => 'Scan your device\'s QR code to connect.';

  @override
  String get addKeystoneBeforeYouStart => 'BEFORE YOU START';

  @override
  String get addKeystoneFirmwareTitle => 'Update to the latest Keystone firmware';

  @override
  String get addKeystoneFirmwareSubtitle => 'Required for QTC signing';

  @override
  String get addKeystoneOnYourKeystone => 'ON YOUR KEYSTONE';

  @override
  String get addKeystoneStepUnlock => 'Unlock your Keystone';

  @override
  String get addKeystoneStepSelectQuantus => 'Select Quantus and scan the QR code';

  @override
  String get addKeystoneReadyToScan => 'Ready to Scan';

  @override
  String get invalidAddress => 'Alamat tidak valid';

  @override
  String get sendTitle => 'Kirim';

  @override
  String get sendPayTitle => 'Bayar';

  @override
  String get sendEnterAddress => 'Masukkan Alamat';

  @override
  String get sendSelectRecipientSendTo => 'Kirim Ke';

  @override
  String sendSelectRecipientSearchHint(String symbol) {
    return 'Masukkan Alamat $symbol';
  }

  @override
  String get sendSelectRecipientScanTitle => 'Pindai kode QR';

  @override
  String sendSelectRecipientScanSubtitle(String symbol) {
    return 'Ketuk untuk memindai Alamat $symbol';
  }

  @override
  String get sendSelectRecipientRecents => 'Terbaru';

  @override
  String get sendSelectRecipientContinue => 'Lanjutkan';

  @override
  String get sendInputAmountSendTo => 'KIRIM KE';

  @override
  String get sendInputAmountAvailableBalance => 'Saldo Tersedia:';

  @override
  String get sendInputAmountNetworkFee => 'Biaya Transaksi:';

  @override
  String get sendInputAmountMax => 'Maks';

  @override
  String get sendInputAmountInvalidAmount => 'Masukkan jumlah yang valid';

  @override
  String get sendInputAmountChecksumRequired => 'Checksum penerima diperlukan';

  @override
  String get sendReviewSending => 'MENGIRIM';

  @override
  String get sendReviewTo => 'KE';

  @override
  String get sendReviewAmount => 'JUMLAH';

  @override
  String get sendReviewNetworkFee => 'BIAYA JARINGAN';

  @override
  String get sendReviewYouPay => 'ANDA BAYAR';

  @override
  String get sendReviewConfirm => 'Konfirmasi';

  @override
  String get sendReviewAuthReason => 'Autentikasi untuk mengonfirmasi transaksi';

  @override
  String get sendReviewAuthRequired => 'Autentikasi diperlukan untuk mengirim';

  @override
  String get sendReviewSubmitFailed => 'Gagal mengirim transaksi';

  @override
  String get sendRegularAccountRequired => 'Beralih ke akun reguler untuk mengirim';

  @override
  String sendTxSubmittedHeadlinePaid(String amount, String symbol) {
    return '$amount $symbol dibayar';
  }

  @override
  String sendTxSubmittedHeadlineSent(String amount, String symbol) {
    return '$amount $symbol terkirim';
  }

  @override
  String get sendTxSubmittedOnItsWay => 'Sedang dalam perjalanan';

  @override
  String get sendTxSubmittedToLabel => 'Ke';

  @override
  String get sendTxSubmittedDone => 'Selesai';

  @override
  String get keystoneSignScreenTitle => 'Sign with Keystone';

  @override
  String keystoneSignStep(int current, int total) {
    return 'STEP $current/$total';
  }

  @override
  String get keystoneSignTitle => 'Pindai dengan Keystone Anda';

  @override
  String get keystoneSignInstruction => 'Open your Keystone and scan this QR code to load the transaction.';

  @override
  String get keystoneSignActionLabel => 'ACTION';

  @override
  String get keystoneSignYouAreSigning => 'YOU ARE SIGNING';

  @override
  String get keystoneSignNext => 'Continue to Sign';

  @override
  String get keystoneSignCancel => 'Cancel Transaction';

  @override
  String get keystoneSignError => 'Gagal menyiapkan transaksi. Silakan coba lagi.';

  @override
  String get keystoneVerifyTitle => 'Check your Keystone Screen';

  @override
  String get keystoneVerifyInstruction => 'Before approving on your Keystone, make sure its screen shows exactly this:';

  @override
  String get keystoneVerifyWarning =>
      'If the amount or address on your Keystone screen is different from what\'s shown here, reject the transaction on your device.';

  @override
  String get keystoneVerifyMismatch => 'It doesn\'t match';

  @override
  String get keystoneScanTitle => 'Scan the signature';

  @override
  String get keystoneScanInstruction =>
      'Your Keystone is now showing an animated QR. Hold your phone up to it, this takes a moment.';

  @override
  String get keystoneScanReceiving => 'RECEIVING SIGNATURE';

  @override
  String keystoneScanProgress(int scanned, int total) {
    return '$scanned/$total';
  }

  @override
  String keystoneScanScanning(int count) {
    return '$count bingkai dipindai';
  }

  @override
  String get keystoneScanSubmitting => 'Mengirim transaksi...';

  @override
  String get keystoneScanError => 'Tidak dapat membaca tanda tangan. Silakan coba lagi.';

  @override
  String get keystoneScanExpired =>
      'Transaksi kedaluwarsa sebelum sempat dikirim. Kembali dan pindai kode QR baru dengan perangkat Anda.';

  @override
  String get keystoneRejectTitle => 'Don\'t approve this transaction';

  @override
  String get keystoneRejectStep1Title => 'Reject the transaction on your Keystone.';

  @override
  String get keystoneRejectStep1Body => 'Nothing is signed or sent until you approve there.';

  @override
  String get keystoneRejectStep2Title => 'Don\'t retry from this phone.';

  @override
  String get keystoneRejectStep2Body => 'If it\'s compromised, retrying gives the attacker another chance.';

  @override
  String get keystoneRejectStep3Title => 'Your funds are safe on the Keystone.';

  @override
  String get keystoneRejectStep3Body => 'Keys never left the device. Move to a trusted phone before sending again.';

  @override
  String get keystoneRejectConfirm => 'I rejected it on Keystone';

  @override
  String get keystoneRejectContactSupport => 'Contact Support';

  @override
  String get sendLogicCantSelfTransfer => 'Tidak Bisa Transfer ke Diri Sendiri';

  @override
  String get sendLogicEnterAmount => 'Masukkan Jumlah';

  @override
  String get sendLogicInvalidAmount => 'Jumlah Tidak Valid';

  @override
  String sendLogicBelowMinimum(String amount, String tokenSymbol) {
    return 'Minimum $amount $tokenSymbol';
  }

  @override
  String get sendLogicInsufficientBalance => 'Saldo Tidak Cukup';

  @override
  String get sendLogicReviewSend => 'Tinjau Pengiriman';

  @override
  String get activityTitle => 'Aktivitas';

  @override
  String activityError(String error) {
    return 'Gagal: $error';
  }

  @override
  String get activityNoAccount => 'Tidak ada akun';

  @override
  String get activityEmpty => 'Belum ada transaksi';

  @override
  String get activityFilterAll => 'Semua';

  @override
  String get activityFilterSend => 'Kirim';

  @override
  String get activityFilterReceive => 'Terima';

  @override
  String get activityDateToday => 'Hari Ini';

  @override
  String get activityDateYesterday => 'Kemarin';

  @override
  String get activityTxSending => 'Mengirim';

  @override
  String get activityTxReceiving => 'Menerima';

  @override
  String get activityTxPending => 'Tertunda';

  @override
  String get activityTxSent => 'Terkirim';

  @override
  String get activityTxReceived => 'Diterima';

  @override
  String get activityTxPrivatelySending => 'Mengirim Secara Privat';

  @override
  String get activityTxPrivatelyReceiving => 'Menerima Secara Privat';

  @override
  String get activityTxPrivateSent => 'Terkirim Privat';

  @override
  String get activityTxPrivateReceived => 'Diterima Privat';

  @override
  String get activityTxMultisigCreated => 'Multisig dibuat';

  @override
  String get activityTxMultisigCreating => 'Membuat multisig';

  @override
  String get activityTxMultisigLabel => 'Multisig';

  @override
  String get activityTxTo => 'Ke';

  @override
  String get activityTxFrom => 'Dari';

  @override
  String get activityTxAggregatedBatch => 'Batch teragregasi';

  @override
  String get activityDetailAggregatedBatch => 'Batch teragregasi, penerima tidak tercatat';

  @override
  String get activityTxTimeNow => 'sekarang';

  @override
  String activityTxTimeMinutesAgo(int minutes) {
    return '${minutes}m lalu';
  }

  @override
  String activityTxTimeHoursAgo(int hours) {
    return '${hours}j lalu';
  }

  @override
  String activityTxTimeDaysAgo(int days) {
    return '${days}h lalu';
  }

  @override
  String activityTxTimeRemaining(String days, String hours, String minutes) {
    return '${days}h:${hours}j:${minutes}m';
  }

  @override
  String get activityDetailTitleSending => 'Mengirim';

  @override
  String get activityDetailTitleScheduled => 'Terjadwal';

  @override
  String get activityDetailTitleReceiving => 'Menerima';

  @override
  String get activityDetailTitleSent => 'Terkirim';

  @override
  String get activityDetailTitleReceived => 'Diterima';

  @override
  String get activityDetailTitlePrivatelySending => 'Mengirim Secara Privat';

  @override
  String get activityDetailTitlePrivatelyReceiving => 'Menerima Secara Privat';

  @override
  String get activityDetailTitlePrivateSent => 'Terkirim Privat';

  @override
  String get activityDetailTitlePrivateReceived => 'Diterima Privat';

  @override
  String get activityDetailTitleMultisigCreated => 'Multisig dibuat';

  @override
  String get activityDetailTitleMultisigCreating => 'Membuat multisig';

  @override
  String get activityDetailTitleProposalCreated => 'Proposal dibuat';

  @override
  String get activityDetailTitleProposalApproved => 'Proposal disetujui';

  @override
  String get activityDetailTitleProposalExecuted => 'Proposal dieksekusi';

  @override
  String get activityDetailTitleProposalCancelled => 'Proposal dibatalkan';

  @override
  String get activityDetailTitleCancelling => 'Membatalkan proposal';

  @override
  String get activityDetailTitleExecuting => 'Mengeksekusi proposal';

  @override
  String get activityDetailTitleProposing => 'Mengajukan';

  @override
  String get activityDetailProposalTransferAmount => 'JUMLAH TRANSFER';

  @override
  String get activityDetailStatusInProcess => 'Diproses';

  @override
  String get activityDetailStatusScheduled => 'Terjadwal';

  @override
  String get activityDetailStatusCompleted => 'Selesai';

  @override
  String get activityDetailStatus => 'STATUS';

  @override
  String get activityDetailTo => 'KE';

  @override
  String get activityDetailFrom => 'DARI';

  @override
  String get activityDetailDate => 'TANGGAL';

  @override
  String get activityDetailNetworkFee => 'BIAYA JARINGAN';

  @override
  String get activityDetailWormholeDetails => 'Detail wormhole';

  @override
  String wormholeDetailsBatch(int index, int count) {
    return 'Batch $index dari $count';
  }

  @override
  String get wormholeDetailsSent => 'TERKIRIM';

  @override
  String get wormholeDetailsChange => 'KEMBALIAN';

  @override
  String get wormholeDetailsInputs => 'INPUT';

  @override
  String get activityDetailTxHash => 'HASH TX';

  @override
  String get activityDetailViewExplorer => 'Lihat di Explorer ↗';

  @override
  String get activityDetailMultisigAddress => 'ALAMAT MULTISIG';

  @override
  String get activityDetailMultisigThreshold => 'AMBANG';

  @override
  String activityDetailMultisigThresholdValue(int threshold, int total) {
    return '$threshold dari $total';
  }

  @override
  String get activityDetailMultisigSignerCount => 'PENANDATANGAN';

  @override
  String get activityDetailMultisigCreator => 'PEMBUAT';

  @override
  String get activityDetailMultisigCreationFee => 'BIAYA PALLET';

  @override
  String get activityDetailMultisigDeposit => 'DEPOSIT TERSIMPAN';

  @override
  String get activityDetailMultisigFeePaidByCreator => 'Dibayar oleh pembuat';

  @override
  String get receiveTitle => 'Terima';

  @override
  String get receiveCopy => 'Salin';

  @override
  String receiveErrorLoadingAccount(String error) {
    return 'Gagal memuat data akun: $error';
  }

  @override
  String get receiveCopiedMessage => 'Alamat disalin ke clipboard';

  @override
  String get receiveYourAddressLabel => 'ALAMAT ANDA';

  @override
  String get receiveCopyAddress => 'Salin Alamat';

  @override
  String get receiveCheckphraseFootnote => 'Minta pengirim mengonfirmasi bahwa frasa ini sesuai dengan alamat Anda.';

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get settingsWalletTitle => 'Dompet';

  @override
  String get settingsWalletSubtitle => 'Frasa Pemulihan, Reset Dompet';

  @override
  String get settingsPreferencesTitle => 'Preferensi';

  @override
  String get settingsPreferencesSubtitle => 'Bahasa, mata uang, notifikasi';

  @override
  String get settingsAccountTypeTitle => 'Tambah Akun';

  @override
  String get settingsAccountTypeSubtitle => 'Kelola akun Anda';

  @override
  String get settingsHelpTitle => 'Bantuan & Dukungan';

  @override
  String get settingsHelpSubtitle => 'FAQ, Hubungi tim';

  @override
  String get settingsAboutTitle => 'Tentang Quantus';

  @override
  String settingsAboutHubSubtitle(String version, String build) {
    return 'Versi $version ($build)';
  }

  @override
  String get settingsWalletRecoveryPhrase => 'Frasa Pemulihan';

  @override
  String get settingsWalletRecoveryPhraseSubtitle => 'Lihat Kata Sandi Cadangan 24 kata Anda';

  @override
  String get settingsWalletReset => 'Reset Dompet';

  @override
  String get settingsWalletResetSubtitle => 'Menghapus semua data dari perangkat ini';

  @override
  String get settingsWalletNoWalletsFound => 'Tidak ada dompet ditemukan';

  @override
  String get settingsWalletFailedToLoad => 'Gagal memuat dompet';

  @override
  String get settingsSelectWalletTitle => 'Pilih Dompet';

  @override
  String get settingsSelectWalletNoWallets => 'Tidak ada dompet ditemukan';

  @override
  String settingsSelectWalletItem(int number) {
    return 'Dompet $number';
  }

  @override
  String get settingsRecoveryConfirmAuthReason => 'Autentikasi untuk melihat frasa pemulihan';

  @override
  String get settingsRecoveryConfirmAuthRequired => 'Autentikasi diperlukan untuk melihat frasa pemulihan';

  @override
  String get settingsRecoveryPhraseTitle => 'Frasa Pemulihan';

  @override
  String get settingsRecoveryPhraseDone => 'Selesai';

  @override
  String get settingsRecoveryAlreadyBackedUp => 'Saya sudah mencadangkan dompet saya';

  @override
  String get settingsResetTitle => 'Reset Dompet';

  @override
  String get settingsResetAuthReason => 'Autentikasi untuk mereset dompet';

  @override
  String settingsResetFailed(String error) {
    return 'Gagal mereset dompet: $error';
  }

  @override
  String get settingsResetAuthRequired => 'Autentikasi diperlukan untuk mereset dompet';

  @override
  String get settingsResetCautionHeadline => 'Ini akan menghapus\ndompet Anda';

  @override
  String get settingsResetCautionBullet1 => 'Semua data dompet akan dihapus permanen dari perangkat ini';

  @override
  String get settingsResetCautionBullet2 =>
      'Dana Anda tetap di blockchain tetapi hanya frasa pemulihan yang dapat memulihkan akses';

  @override
  String get settingsResetCautionBullet3 => 'Tanpa frasa pemulihan, dana Anda hilang selamanya';

  @override
  String get settingsResetCautionCheckbox => 'Saya sudah mencadangkan frasa pemulihan saya';

  @override
  String get settingsPreferencesCurrency => 'Mata Uang';

  @override
  String get settingsPreferencesCurrencySubtitle => 'Preferensi tampilan fiat';

  @override
  String get settingsPreferencesLanguage => 'Bahasa';

  @override
  String get settingsPreferencesLanguageSubtitle => 'Bahasa tampilan aplikasi';

  @override
  String get settingsPreferencesNotifications => 'Notifikasi';

  @override
  String get settingsPreferencesNotificationsSubtitle => 'Peringatan transaksi dan dompet';

  @override
  String get settingsCurrencyTitle => 'Mata Uang';

  @override
  String get settingsCurrencySearchHint => 'Cari';

  @override
  String get settingsCurrencyNoMatch => 'Tidak ada mata uang yang cocok dengan pencarian Anda';

  @override
  String settingsCurrencyError(String error) {
    return 'Gagal memilih mata uang: $error';
  }

  @override
  String get settingsLanguageTitle => 'Bahasa';

  @override
  String get settingsLanguageSearchHint => 'Cari';

  @override
  String get settingsLanguageNoMatch => 'Tidak ada bahasa yang cocok dengan pencarian Anda';

  @override
  String settingsLanguageError(String error) {
    return 'Gagal memilih bahasa: $error';
  }

  @override
  String get settingsHelpScreenTitle => 'Bantuan & Dukungan';

  @override
  String get settingsHelpEmail => 'Dukungan Email';

  @override
  String get settingsHelpTelegram => 'Telegram';

  @override
  String get settingsAboutScreenTitle => 'Tentang';

  @override
  String get settingsAboutIntro =>
      'Quantus adalah blockchain Layer 1 yang diamankan oleh ML-DSA Dilithium-5, standar emas enkripsi tahan kuantum. Dibangun untuk masa depan di mana kriptografi klasik tidak lagi cukup. Kriptografi pasca-kuantum untuk semua orang.';

  @override
  String get settingsAboutTerms => 'Ketentuan Layanan';

  @override
  String get settingsAboutTermsSubtitle => 'quantus.com/terms/';

  @override
  String get settingsAboutPrivacy => 'Kebijakan privasi';

  @override
  String get settingsAboutPrivacySubtitle => 'quantus.com/privacy-policy/';

  @override
  String get settingsAboutWebsite => 'Kunjungi Situs Web';

  @override
  String get settingsAboutWebsiteSubtitle => 'quantus.com';

  @override
  String settingsAboutVersion(String version, String build) {
    return 'Versi $version ($build)';
  }

  @override
  String get swapTitle => 'Tukar';

  @override
  String get swapPoweredBy => 'Didukung Oleh';

  @override
  String get swapFrom => 'Dari';

  @override
  String get swapTo => 'Ke';

  @override
  String get swapExternalWallet => 'Dompet yang Anda kendalikan';

  @override
  String get swapRate => 'Kurs';

  @override
  String swapRateLabel(String fromSymbol, String rate, String toSymbol) {
    return '1 $fromSymbol = $rate $toSymbol';
  }

  @override
  String swapSlippageLabel(String percent) {
    return 'Slippage $percent%';
  }

  @override
  String get swapSlippageTitle => 'Toleransi Slippage';

  @override
  String get swapSlippageBody =>
      'Jika harga bergerak lebih dari ini sebelum swap Anda terisi, dana dikembalikan. Toleransi lebih tinggi lebih sering terisi tetapi hasilnya bisa lebih sedikit.';

  @override
  String swapSlippagePercent(String percent) {
    return '$percent%';
  }

  @override
  String get swapAddRecipientAddress => 'Tambahkan Alamat Penerima';

  @override
  String get swapAddRefundAddress => 'Tambahkan Alamat Refund';

  @override
  String get swapTokenPickerTitle => 'Pilih Token';

  @override
  String get swapTokenPickerLoadError => 'Gagal memuat token';

  @override
  String swapQuoteError(String message) {
    return 'Penawaran gagal: $message';
  }

  @override
  String get swapRecipientAddressTitle => 'Alamat Penerima';

  @override
  String get swapRefundAddressTitle => 'Alamat Refund';

  @override
  String swapAddressLabel(String symbol) {
    return 'Alamat $symbol';
  }

  @override
  String swapAddressHint(String network) {
    return 'Alamat $network';
  }

  @override
  String swapRecipientAddressNotice(String symbol) {
    return '$symbol Anda akan tiba di alamat ini. Periksa kembali, swap tidak dapat dibatalkan.';
  }

  @override
  String swapRefundAddressNotice(String symbol, String network) {
    return 'Jika swap tidak dapat diselesaikan, $symbol Anda dikembalikan ke alamat ini di $network. Periksa kembali.';
  }

  @override
  String get swapSaveAddress => 'Simpan untuk swap berikutnya';

  @override
  String get swapContinue => 'Lanjutkan ke Swap';

  @override
  String get swapSavedAddressesTitle => 'Alamat Tersimpan';

  @override
  String get swapSavedAddressesEmpty => 'Belum ada alamat tersimpan';

  @override
  String get swapReviewTitle => 'Tinjau Swap';

  @override
  String get swapYouPay => 'Anda bayar';

  @override
  String get swapYouReceive => 'Anda terima';

  @override
  String get swapReviewRecipient => 'Penerima';

  @override
  String get swapReviewRefundAddress => 'Alamat refund';

  @override
  String get swapReviewNetworkFee => 'Biaya jaringan';

  @override
  String get swapReviewFeeUnavailable => 'Tidak tersedia';

  @override
  String get swapReviewFeeFailed => 'Tidak dapat mengambil biaya jaringan.';

  @override
  String get swapReviewSlippage => 'Toleransi slippage';

  @override
  String swapReviewSlippageValue(String amount, String percent) {
    return '$amount ($percent%)';
  }

  @override
  String get swapReviewGuaranteedMinimum => 'Minimum terjamin';

  @override
  String swapReviewInsufficient(String symbol) {
    return '$symbol tidak cukup untuk jumlah ini ditambah biaya jaringan.';
  }

  @override
  String get swapReviewPriceMoved => 'Harga berubah. Periksa jumlah baru dan konfirmasi lagi.';

  @override
  String get swapReviewConfirm => 'Konfirmasi swap';

  @override
  String get swapInProgressTitle => 'Swap Sedang Berjalan';

  @override
  String get swapYourePaying => 'Anda membayar';

  @override
  String get swapYoureReceiving => 'Anda menerima';

  @override
  String swapStepSent(String symbol) {
    return '$symbol terkirim';
  }

  @override
  String swapStepConfirming(String network) {
    return 'Mengonfirmasi di $network';
  }

  @override
  String get swapStepSwapping => 'Menukar';

  @override
  String swapStepSending(String symbol, String recipient) {
    return 'Mengirim $symbol ke $recipient';
  }

  @override
  String get swapProgressFooter =>
      'Biasanya beberapa menit. Swap tetap selesai meskipun Anda meninggalkan layar ini. · via NEAR Intents';

  @override
  String get swapDetailsTitle => 'Detail Swap';

  @override
  String get swapDetailsRecipient => 'Alamat penerima';

  @override
  String get swapDetailsAmountSent => 'Jumlah dikirim';

  @override
  String get swapDetailsExpected => 'Perkiraan';

  @override
  String get swapDetailsTransaction => 'Transaksi';

  @override
  String get swapCompleteTitle => 'Swap Selesai';

  @override
  String get swapCompleteReceived => 'Diterima';

  @override
  String get swapCompleteTo => 'Ke:';

  @override
  String get swapFailedTitle => 'Swap Gagal';

  @override
  String get swapRefundedLabel => 'Dikembalikan';

  @override
  String get swapYouPaid => 'Anda telah membayar';

  @override
  String get swapYouWereReceiving => 'Anda akan menerima';

  @override
  String swapRefundedBody(String amount, String destination, String symbol) {
    return 'Swap tidak dapat diselesaikan, jadi $amount Anda telah dikembalikan ke $destination, dikurangi biaya jaringan. $symbol tidak pernah dikirim.';
  }

  @override
  String swapDepositRefundReason(String reason) {
    return 'Alasan: $reason';
  }

  @override
  String swapDepositFailedBody(String address) {
    return 'Swap tidak selesai. Hubungi dukungan dan sebutkan alamat deposit ini: $address';
  }

  @override
  String get swapDepositIncompleteTitle => 'Deposit Terlalu Kecil';

  @override
  String get swapDepositIncompleteBody =>
      'Jumlah yang tiba kurang dari penawaran. Dana akan dikembalikan ke alamat refund Anda setelah tenggat waktu.';

  @override
  String get swapDepositExpiredTitle => 'Penawaran Kedaluwarsa';

  @override
  String get swapDepositExpiredBody =>
      'Tidak ada deposit yang tiba sebelum tenggat waktu. Jangan kirim dana ke alamat ini lagi. Minta penawaran baru untuk mencoba lagi.';

  @override
  String get swapStartNew => 'Mulai Swap Baru';

  @override
  String get swapContactSupport => 'Hubungi Dukungan';

  @override
  String get swapDepositAmount => 'Jumlah Deposit';

  @override
  String get swapDepositAmountCopied => 'Jumlah deposit disalin ke clipboard';

  @override
  String get swapDepositAddressCopied => 'Alamat deposit disalin ke clipboard';

  @override
  String get swapDepositWaiting => 'Menunggu deposit Anda…';

  @override
  String swapDepositDeadline(String time) {
    return 'Kirim sebelum $time atau penawaran kedaluwarsa';
  }

  @override
  String get swapDepositShareQr => 'Bagikan QR';

  @override
  String swapDepositShareContent(String network, String token, String address) {
    return 'Jaringan: $network\nToken: $token\nAlamat: $address';
  }

  @override
  String swapDepositNotice(String symbol, String network) {
    return 'Gunakan dompet $symbol atau $network Anda untuk deposit. Menyetor aset lain dapat mengakibatkan kehilangan dana.';
  }

  @override
  String get componentQrScannerTitle => 'Pindai Kode QR';

  @override
  String get componentQrScannerNoCode => 'Tidak ada kode QR pada gambar';

  @override
  String get componentShare => 'Bagikan';

  @override
  String get componentAddressLabel => 'ALAMAT';

  @override
  String get componentCheckphraseLabel => 'CHECKPHRASE';

  @override
  String get componentCheckphraseCopied => 'Checkphrase disalin';

  @override
  String get componentNameFieldHint => 'Masukkan nama untuk akun Anda';

  @override
  String get componentAmountApproximatePrefix => '≈';

  @override
  String get commonLoading => 'Memuat...';

  @override
  String get commonCancel => 'Batal';

  @override
  String get commonCanceling => 'Membatalkan...';

  @override
  String commonAmountBalance(String balance, String symbol) {
    return '$balance $symbol';
  }

  @override
  String get commonContinue => 'Lanjutkan';

  @override
  String get commonDone => 'Selesai';

  @override
  String get commonRetry => 'Coba Lagi';

  @override
  String get commonTryAgain => 'Coba Lagi';

  @override
  String get redeemCancel => 'Batal';

  @override
  String get redeemClose => 'Tutup';

  @override
  String get encryptedSendFeeLabel => 'Biaya transaksi';

  @override
  String encryptedSendAmountStep(String tokenSymbol) {
    return 'Gunakan kelipatan 0,01 $tokenSymbol';
  }

  @override
  String encryptedSendMinimum(String tokenSymbol) {
    return 'Pengiriman terenkripsi minimal 0,1 $tokenSymbol';
  }

  @override
  String get encryptedSendProgressTitle => 'Mengirim Secara Privat...';

  @override
  String get encryptedSendFailedTitle => 'Pengiriman Gagal';

  @override
  String get encryptedSendCancelledTitle => 'Pengiriman Dibatalkan';

  @override
  String get encryptedSendingLabel => 'MENGIRIM';

  @override
  String get encryptedSendStepPreparing => 'Mempersiapkan';

  @override
  String get encryptedSendStepGathering => 'Mengumpulkan dana';

  @override
  String get encryptedSendStepSecuring => 'Mengamankan transaksi';

  @override
  String get encryptedSendStepGenerating => 'Membuat bukti';

  @override
  String get encryptedSendStepProving => 'Membangun bukti privasi';

  @override
  String get encryptedSendStepSubmitting => 'Mengirim ke chain';

  @override
  String get encryptedSendProgressFooter =>
      'Privasi membutuhkan waktu. Harap biarkan aplikasi tetap terbuka sampai transaksi selesai.';

  @override
  String encryptedSendCancelledPartial(String amount) {
    return '$amount sudah terkirim sebelum dibatalkan. Sisanya tetap berada di akun Anda.';
  }

  @override
  String get encryptedSendFundsSafeLabel => 'Dana Anda aman';

  @override
  String encryptedSendFundsSafeCaption(String account) {
    return 'Masih di $account. Tidak ada yang keluar dari dompet Anda.';
  }

  @override
  String get privateSendTitle => 'Kirim Privat';

  @override
  String get privateSendSubtitle => 'Menyembunyikan kaitan antara akun Anda dan penerima';

  @override
  String get encryptedSendPlanStale =>
      'Saldo terenkripsi Anda berubah saat meninjau. Silakan kembali dan masukkan jumlahnya lagi.';

  @override
  String get mainnetMigrationTitle => 'Quantus kini aktif di *mainnet*.';

  @override
  String get mainnetMigrationChecking => 'Testnet telah ditutup. Kami sedang memeriksa artinya untuk wallet ini.';

  @override
  String get mainnetMigrationReadingHistory => 'Membaca riwayat testnet';

  @override
  String mainnetMigrationBlocksMinedCount(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString';
  }

  @override
  String get mainnetMigrationBlocksMined => 'Blok ditambang di testnet';

  @override
  String get mainnetMigrationMinerTitle => 'Simpan wallet ini.';

  @override
  String get mainnetMigrationMinerBody =>
      'Hadiah Anda aman. Hadiah terikat pada wallet ini dan tiba setelah peluncuran. Saldo Anda dimulai dari nol karena hadiah dihitung dari blok yang ditambang, bukan dari saldo testnet Anda.';

  @override
  String get mainnetMigrationNotMinedTitle => 'Tidak ada yang dibawa.';

  @override
  String mainnetMigrationNotMinedBody(String tokenSymbol) {
    return 'Saldo testnet Anda tetap di testnet. Koin itu hanya untuk pengujian, jadi wallet ini dimulai dari nol $tokenSymbol.';
  }

  @override
  String get mainnetMigrationUnreachableBadge => 'Tidak dapat diperiksa';

  @override
  String get mainnetMigrationUnreachableTitle => 'Kami tidak dapat memeriksa wallet ini.';

  @override
  String mainnetMigrationUnreachableBody(String tokenSymbol) {
    return 'Testnet tidak dapat dijangkau, jadi kami belum tahu apakah Anda menambang. Saldo Anda tetap dimulai dari nol $tokenSymbol.';
  }

  @override
  String get mainnetMigrationUnreachableRewards =>
      'Jika Anda menambang, hadiah Anda aman. Hadiah tetap terikat pada wallet ini, baik kami dapat memeriksanya hari ini maupun tidak.';

  @override
  String get mainnetMigrationKeepWallet => 'Simpan wallet ini';

  @override
  String get mainnetMigrationCreateWallet => 'Buat wallet baru';

  @override
  String get mainnetMigrationCreateDialogTitle => 'Buat wallet baru?';

  @override
  String get mainnetMigrationCreateDialogBody =>
      'Anda akan mendapat frasa rahasia baru untuk dicatat dan disimpan dengan aman. Wallet ini tetap ada di perangkat.';

  @override
  String get mainnetMigrationCreateDialogUncheckedTitle => 'Kami tidak dapat memeriksa wallet ini';

  @override
  String get mainnetMigrationCreateDialogUncheckedBody => 'Jadi kami tidak tahu apakah Anda menambang di testnet.';

  @override
  String get mainnetMigrationCreateDialogUncheckedAdvice =>
      'Jika Anda menambang, hadiah Anda terikat pada wallet ini. Sebaiknya simpan wallet ini dan coba lagi nanti.';

  @override
  String get mainnetMigrationCreateDialogConfirm => 'Buat wallet baru';

  @override
  String get mainnetMigrationCreateDialogCancel => 'Simpan wallet saya';

  @override
  String get mainnetMigrationAllSetBadge => 'Mainnet';

  @override
  String get mainnetMigrationAllSetTitle => 'Semua sudah siap.';

  @override
  String mainnetMigrationAllSetBody(String tokenSymbol) {
    return 'Mulai sekarang semuanya adalah uang sungguhan. Tambahkan $tokenSymbol kapan pun Anda siap.';
  }

  @override
  String mainnetMigrationGetTokens(String tokenSymbol) {
    return 'Dapatkan $tokenSymbol';
  }

  @override
  String get mainnetMigrationGoToWallet => 'Ke wallet';

  @override
  String mainnetMigrationSaveFailed(String error) {
    return 'Pilihan Anda tidak dapat disimpan: $error';
  }

  @override
  String get settingsMiningRewards => 'Mining Rewards';

  @override
  String get settingsMiningRewardsSubtitle => 'Claim your testnet mining rewards';

  @override
  String miningRewardsHeroTitle(String symbol) {
    return 'Testnet mining paid out in $symbol.';
  }

  @override
  String get miningRewardsHeroBody =>
      'Rewards are based on the blocks you mined on Resonance, Schrödinger, Dirac, and Planck testnets. Amounts are already set.';

  @override
  String get settingsSelectWalletSection => 'Wallets on the device';

  @override
  String miningRewardsCheckingAddresses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Checking $count addresses',
      one: 'Checking 1 address',
    );
    return '$_temp0';
  }

  @override
  String miningRewardsProgressOf(int total) {
    return 'of $total';
  }

  @override
  String get miningRewardsTotalRewards => 'Total rewards';

  @override
  String miningRewardsBlocks(int count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$countString blocks', one: '1 block');
    return '$_temp0';
  }

  @override
  String get miningRewardsNotMined => 'Not mined';

  @override
  String get miningRewardsSheetBlocksMined => 'Blocks mined';

  @override
  String get miningRewardsSheetReward => 'Reward';

  @override
  String get miningRewardsNoMiningTitle => 'No mining on this wallet';

  @override
  String get miningRewardsNoMiningBody1 =>
      'We checked your addresses against Resonance, Schrödinger, Dirac and Planck, and found no blocks.';

  @override
  String get miningRewardsNoMiningBody2 => 'If you mined with a different wallet, go back and choose it.';

  @override
  String get miningRewardsTryAnotherWallet => 'Try another wallet';

  @override
  String get miningRewardsPayToIntro => 'Enter the address we should send the rewards to';

  @override
  String get miningRewardsUseAnotherAddress => 'Use Another Address';

  @override
  String get miningRewardsAnotherAddressTitle => 'Another Address';

  @override
  String get miningRewardsDestinationLabel => 'Destination';

  @override
  String miningRewardsPasteAddressHint(String symbol) {
    return 'Paste $symbol Address';
  }

  @override
  String get miningRewardsAddressAdvice =>
      'Use an address you control. Rewards sent to an address you don\'t own can\'t be recovered.';

  @override
  String miningRewardsAddressInvalid(String symbol) {
    return 'This isn\'t a valid $symbol address. Check the last few characters.';
  }

  @override
  String get miningRewardsConfirmTitle => 'Confirm Destination';

  @override
  String get miningRewardsClaimingLabel => 'Claiming';

  @override
  String get miningRewardsAmountLabel => 'Amount';

  @override
  String get miningRewardsPayoutLabel => 'Payout';

  @override
  String get miningRewardsPayoutWindow => 'Within a week';

  @override
  String get miningRewardsChangeDetails => 'Change Details';

  @override
  String get miningRewardsSubmitFailedTitle => 'Couldn\'t submit right now';

  @override
  String get miningRewardsSubmitFailedBody1 => 'Something went wrong reaching the network.';

  @override
  String get miningRewardsSubmitFailedBody2 =>
      'Your rewards are safe. Nothing expires and there is no deadline to claim.';

  @override
  String get miningRewardsSubmitPartialTitle => 'Some claims have been submitted';

  @override
  String get miningRewardsSubmitPartialBody => 'Please try again to submit the rest.';

  @override
  String get miningRewardsSubmittedAll => 'All claims have been submitted.';

  @override
  String miningRewardsSubmittedPayingTo(String destination) {
    return 'Paying to $destination.';
  }

  @override
  String get miningRewardsSubmittedNote => 'Payouts go out within a week. Nothing else to do.';

  @override
  String miningRewardsClaimedOn(String date) {
    return 'Claimed $date';
  }

  @override
  String get miningRewardsPayingTo => 'Paying To';

  @override
  String get miningRewardsCheckAnotherWallet => 'Check another wallet';

  @override
  String get miningRewardsWalletsLabel => 'Wallets';

  @override
  String get miningRewardsClaimedTag => 'Claimed';

  @override
  String get miningRewardsNotClaimed => 'Not claimed yet';

  @override
  String get miningRewardsCheckEligibility => 'Check eligibility';

  @override
  String get miningRewardsNotClaimable => 'Claim not available yet';

  @override
  String get miningRewardsCheckFailed => 'Check failed, tap to retry';

  @override
  String get miningRewardsClaim => 'Claim';

  @override
  String get miningRewardsSubmitClaims => 'Submit Claim';
}
