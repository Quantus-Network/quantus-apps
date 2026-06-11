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
  String get homeCharge => 'Tagih';

  @override
  String get homeGetTestnetTokens => 'Dapatkan Token Testnet ↗';

  @override
  String get homeErrorLoadingBalance => 'Gagal memuat saldo';

  @override
  String get homeBackupReminder => 'Cadangkan recovery phrase Anda';

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
  String get homeActivityEmptyMessage => 'Aktivitas Anda akan muncul di sini setelah Anda mengirim atau menerima QUAN.';

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
  String get addAccountMenuTitle => 'Tambah Akun';

  @override
  String get addAccountMenuCreateTitle => 'Buat Akun Baru';

  @override
  String get addAccountMenuCreateSubtitle => 'Buat alamat wallet baru';

  @override
  String get addAccountMenuImportTitle => 'Impor Wallet';

  @override
  String get addAccountMenuImportSubtitle => 'Gunakan recovery phrase untuk mengimpor';

  @override
  String get createAccountAppBarTitle => 'Nama Akun';

  @override
  String get createAccountSubtitle => 'Berikan nama yang mudah Anda kenali. Anda bisa mengubahnya kapan saja.';

  @override
  String get createAccountButton => 'Buat';

  @override
  String get createAccountErrorCouldNotAdd => 'Gagal menambahkan akun.';

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
  String get accountMenuShowRecoveryPhrase => 'Tampilkan Recovery Phrase';

  @override
  String get accountMenuNotFound => 'Akun tidak ditemukan';

  @override
  String get accountDetailsTitle => 'Detail Alamat';

  @override
  String get addHardwareAccountAddWallet => 'Tambah Hardware Wallet';

  @override
  String get addHardwareAccountAddAccount => 'Tambah Akun Hardware';

  @override
  String get addHardwareAccountNameLabel => 'NAMA';

  @override
  String get addHardwareAccountNameHintWallet => 'Hardware Wallet';

  @override
  String get addHardwareAccountNameHintAccount => 'Akun';

  @override
  String get addHardwareAccountAddressLabel => 'ALAMAT';

  @override
  String get addHardwareAccountAddressHint => 'Alamat SS58';

  @override
  String get addHardwareAccountDebugFill => 'Isi Debug';

  @override
  String get addHardwareAccountNameRequired => 'Nama wajib diisi';

  @override
  String get addHardwareAccountInvalidAddress => 'Alamat tidak valid';

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
  String get sendInputAmountNetworkFee => 'Biaya Jaringan:';

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
  String get sendLogicCantSelfTransfer => 'Tidak Bisa Transfer ke Diri Sendiri';

  @override
  String get sendLogicEnterAmount => 'Masukkan Jumlah';

  @override
  String get sendLogicInvalidAmount => 'Jumlah Tidak Valid';

  @override
  String get sendLogicBelowExistentialDeposit => 'Di Bawah Deposit Eksistensial';

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
  String get activityTxTo => 'Ke';

  @override
  String get activityTxFrom => 'Dari';

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
  String get activityDetailTxHash => 'HASH TX';

  @override
  String get activityDetailViewExplorer => 'Lihat di Explorer ↗';

  @override
  String get receiveTitle => 'Terima';

  @override
  String get receiveTabQrCode => 'Kode QR';

  @override
  String get receiveTabAddress => 'Alamat';

  @override
  String get receiveCopy => 'Salin';

  @override
  String receiveErrorLoadingAccount(String error) {
    return 'Gagal memuat data akun: $error';
  }

  @override
  String receiveClipboardContent(String accountId, String checksum) {
    return 'ID Akun:\n$accountId\n\nCheckphrase:\n$checksum';
  }

  @override
  String get receiveCopiedMessage => 'Detail akun disalin ke clipboard';

  @override
  String get posAmountTitle => 'Tagihan Baru';

  @override
  String posAmountCharge(String amount) {
    return 'Tagih $amount';
  }

  @override
  String get posAmountEnterAmount => 'Masukkan Jumlah';

  @override
  String get posQrTitleScanToPay => 'Pindai untuk Bayar';

  @override
  String get posQrTitlePaymentReceived => 'Pembayaran Diterima';

  @override
  String posQrError(String error) {
    return 'Gagal: $error';
  }

  @override
  String get posQrNoActiveAccount => 'Tidak ada akun aktif';

  @override
  String get posQrInvalidAmount => 'Jumlah tidak valid. Ketuk untuk coba lagi.';

  @override
  String get posQrConnectionLost => 'Koneksi terputus. Ketuk untuk coba lagi.';

  @override
  String get posQrTimedOut => 'Waktu habis. Ketuk untuk coba lagi.';

  @override
  String get posQrNewCharge => 'Tagihan Baru';

  @override
  String get posQrDone => 'Selesai';

  @override
  String posQrAmountReceived(String amount) {
    return '$amount diterima';
  }

  @override
  String get posQrFrom => 'Dari:';

  @override
  String get posQrWaitingForPayment => 'Menunggu pembayaran';

  @override
  String get posQrNetworkError => 'Jaringan Bermasalah';

  @override
  String get posQrTryAgain => 'Coba Lagi';

  @override
  String posQrPaidAt(String time) {
    return 'Pada $time';
  }

  @override
  String get settingsTitle => 'Pengaturan';

  @override
  String get settingsWalletTitle => 'Dompet';

  @override
  String get settingsWalletSubtitle => 'Frasa Pemulihan, Reset Dompet';

  @override
  String get settingsPreferencesTitle => 'Preferensi';

  @override
  String get settingsPreferencesSubtitle => 'Bahasa, mata uang, mode POS, notifikasi';

  @override
  String get settingsMiningRewards => 'Hadiah Mining';

  @override
  String settingsMiningRewardsSubtitle(int count) {
    return '$count blok ditambang';
  }

  @override
  String get settingsMiningRewardsError => 'Gagal memuat hadiah mining';

  @override
  String get settingsAccountTypeTitle => 'Jenis Akun';

  @override
  String get settingsAccountTypeSubtitle => 'Fitur Akun Lanjutan';

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
  String get settingsPreferencesPosMode => 'Mode POS';

  @override
  String get settingsPreferencesPosModeSubtitle => 'Fitur point of sale';

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
  String get settingsMiningTitle => 'Hadiah Mining';

  @override
  String get settingsMiningRedeem => 'Tukar';

  @override
  String get settingsMiningStatusMining => 'Mining';

  @override
  String get settingsMiningStatusPending => 'Menunggu';

  @override
  String get settingsMiningBlocksMined => 'BLOK DITAMBANG';

  @override
  String get settingsMiningBlocksAcrossTestnets => 'blok di semua testnet';

  @override
  String get settingsMiningStatTestnetBlocks => 'BLOK TESTNET';

  @override
  String get settingsMiningStatTestnetRewards => 'HADIAH TESTNET';

  @override
  String get settingsMiningStatRedeemed => 'DITUKAR';

  @override
  String get settingsMiningStatRedeemable => 'DAPAT DITUKAR';

  @override
  String get settingsMiningQuanEarned => 'QUAN DIHASILKAN';

  @override
  String get settingsMiningViewTelemetry => 'Lihat Telemetri ↗';

  @override
  String get settingsMiningNoDataTitle => 'Belum ada data mining';

  @override
  String get settingsMiningNoDataBody => 'Siapkan node mining Quantus untuk mulai mendapatkan hadiah.';

  @override
  String get settingsMiningSetupGuide => 'Panduan Setup Mining ↗';

  @override
  String get settingsMiningLoadError => 'Gagal memuat hadiah mining';

  @override
  String get settingsMiningCheckConnection => 'Periksa koneksi Anda';

  @override
  String get settingsMiningTestnetBlocks => 'blok';

  @override
  String get settingsMiningDiracSince => 'Nov 2025';

  @override
  String get settingsMiningSchrodingerSince => 'Okt 2025';

  @override
  String get settingsMiningResonanceSince => 'Jul 2025';

  @override
  String get settingsTestnetTitle => 'Hadiah Testnet';

  @override
  String get settingsTestnetLoadError => 'Gagal memuat hadiah testnet';

  @override
  String settingsTestnetTotalBlocks(int count) {
    return '$count blok';
  }

  @override
  String get settingsTestnetTotalDescription => 'Total blok ditambang di semua testnet';

  @override
  String get settingsTestnetBreakdown => 'Rincian';

  @override
  String settingsTestnetRowBlocks(int count) {
    return '$count blok';
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
  String get settingsAccountTypeScreenTitle => 'Jenis Akun';

  @override
  String get settingsAccountTypeIntro =>
      'Fitur akun lanjutan akan segera hadir. Fitur ini memberi Anda kontrol lebih besar atas cara transaksi diotorisasi dan diamankan.';

  @override
  String get settingsAccountTypeReversibleTitle => 'Transaksi Reversible';

  @override
  String get settingsAccountTypeReversibleSubtitle => 'Batalkan pengiriman dalam jangka waktu tertentu';

  @override
  String get settingsAccountTypeHighSecurityTitle => 'Akun Keamanan Tinggi';

  @override
  String get settingsAccountTypeHighSecuritySubtitle => 'Persetujuan guardian diperlukan';

  @override
  String get settingsAccountTypeMultiSigTitle => 'Multi-Tanda Tangan';

  @override
  String get settingsAccountTypeMultiSigSubtitle => 'Beberapa persetujuan diperlukan';

  @override
  String get settingsAccountTypeHardwareTitle => 'Dompet Hardware';

  @override
  String get settingsAccountTypeHardwareSubtitle => 'Pasangkan perangkat hardware';

  @override
  String get settingsAccountTypeComingSoon => 'Segera Hadir';

  @override
  String get swapTitle => 'Tukar';

  @override
  String get swapFrom => 'Dari';

  @override
  String get swapTo => 'Ke';

  @override
  String get swapRefundAddress => 'Alamat Refund';

  @override
  String swapRefundAddressHint(String network) {
    return 'Alamat $network';
  }

  @override
  String get swapSlippageTolerance => 'Toleransi Slippage';

  @override
  String get swapRate => 'Kurs';

  @override
  String get swapGetQuote => 'Dapatkan Penawaran';

  @override
  String swapRateLabel(String amount, String symbol) {
    return '1 QUAN = $amount $symbol';
  }

  @override
  String swapRateZero(String symbol) {
    return '1 QUAN = 0 $symbol';
  }

  @override
  String get swapTokenPickerTitle => 'Pilih Token';

  @override
  String get swapTokenPickerLoadError => 'Gagal memuat token';

  @override
  String get swapReviewTitle => 'Tinjau Penawaran';

  @override
  String get swapReviewTotalFees => 'Total biaya';

  @override
  String get swapReviewTotalAmount => 'Jumlah Total';

  @override
  String swapReviewSlippageWarning(String amount, String percent) {
    return 'Anda bisa menerima hingga \$$amount lebih sedikit berdasarkan slippage $percent% yang Anda atur';
  }

  @override
  String get swapReviewConfirm => 'Konfirmasi';

  @override
  String get swapDepositAmount => 'Jumlah Deposit';

  @override
  String get swapDepositAmountCopied => 'Jumlah deposit disalin ke clipboard';

  @override
  String get swapDepositDemoWarning => 'Hanya untuk demo - jangan kirim dana!';

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
  String get swapDepositProcessingTitle => 'Memproses Swap';

  @override
  String get swapDepositProcessingBody => 'Ini mungkin memakan waktu beberapa menit...';

  @override
  String get swapDepositCompleteTitle => 'Swap Selesai';

  @override
  String swapDepositCompleteBody(String amount) {
    return 'Swap Anda untuk $amount QUAN telah selesai.';
  }

  @override
  String get swapDepositTestnetBanner => 'HANYA DEMO - KAMI MASIH DI TESTNET';

  @override
  String get swapDepositSentFunds => 'Saya sudah mengirim dana';

  @override
  String get swapDepositDone => 'Selesai';

  @override
  String get swapRefundPickerTitle => 'Alamat Refund';

  @override
  String get swapRefundPickerEmpty => 'Tidak ada alamat refund terbaru';

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
  String get commonLoading => 'Memuat...';

  @override
  String commonAmountBalance(String balance, String symbol) {
    return '$balance $symbol';
  }

  @override
  String get commonContinue => 'Lanjutkan';
}
