// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get walletInitErrorTitle => 'Wallet Eror';

  @override
  String get walletInitErrorMessage => 'Gagal mencari secret phrase. Coba pulihkan wallet anda.';

  @override
  String get walletInitErrorButtonLabel => 'OK';

  @override
  String get authUseDeviceBiometricsToUnlock => 'Gunakan biometrik untuk membuka perangkat';

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
  String get createWalletAppBarTitle => 'Buat Wallet';

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
  String get createWalletCautionCheckboxLabel =>
      'Saya memahami bahwa siapa pun yang memiliki recovery phrase saya dapat mengakses wallet saya. Saya akan menyimpannya dengan aman.';

  @override
  String get createWalletCautionContinue => 'Lanjutkan';

  @override
  String get createWalletRecoveryPhraseNext => 'Berikutnya';

  @override
  String createWalletRecoveryPhraseFailedGenerate(String error) {
    return 'Gagal membuat: $error';
  }

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
    return 'Eror: $error';
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
  String get accountsSheetLoading => 'Memuat...';

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
  String get addHardwareAccountScanQr => 'Pindai Kode QR';

  @override
  String get addHardwareAccountDebugFill => 'Isi Debug';

  @override
  String get addHardwareAccountNameRequired => 'Nama wajib diisi';

  @override
  String get addHardwareAccountInvalidAddress => 'Alamat tidak valid';
}
