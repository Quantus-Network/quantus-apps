import 'dart:convert';
import 'dart:ui';

import 'package:http/http.dart' as http;
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/referral_data.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:share_plus/share_plus.dart';

class ReferralService {
  static final ReferralService _instance = ReferralService._internal();
  factory ReferralService() => _instance;
  ReferralService._internal();

  final SettingsService _settingsService = SettingsService();
  final HumanReadableChecksumService _checksumService = HumanReadableChecksumService();
  final TaskmasterService _taskmasterService = TaskmasterService();

  bool? _rewardProgramParticipationCache;
  bool _hasCheckedReferralData = false;
  String? _referralDataCache;

  // This fetches any available referral code from the google play store and stores
  // it in settings if found.
  Future<void> checkPlayStoreReferralCode() async {
    // Only check once - on first launch after install
    bool hasChecked = _settingsService.referralCheckCompleted();
    if (hasChecked) return;

    try {
      ReferrerDetails referrerDetails = await PlayInstallReferrer.installReferrer;
      String? referrerString = referrerDetails.installReferrer;

      quantusDebugPrint('Raw Install Referrer: $referrerString');

      if (referrerString != null && referrerString.isNotEmpty) {
        Map<String, String> params = _parseReferrer(referrerString);

        String? referralCode = params['referral_code'];

        if (referralCode != null && referralCode.isNotEmpty) {
          SettingsService().setReferralCode(referralCode);
          SettingsService().setReferralCheckCompleted();
          quantusDebugPrint('Referral Code Found: $referralCode');
        }
      }

      quantusDebugPrint('No referral code found');
    } catch (e) {
      quantusDebugPrint('Error checking install referrer: $e');
    }
  }

  Future<void> optInRewardProgram() async {
    await _taskmasterService.optInRewardProgram();
    _rewardProgramParticipationCache = true;
  }

  Map<String, String> _parseReferrer(String referrer) {
    Map<String, String> params = {};

    Uri uri = Uri.parse('?$referrer');
    params = Map.from(uri.queryParameters);

    return params;
  }

  Future<String?> getReferralData() async {
    if (_hasCheckedReferralData) {
      return _referralDataCache;
    }

    final account = await getMainAccount();
    final getReferralByRefereeUri = Uri.parse('${AppConstants.taskMasterEndpoint}/referrals/${account.accountId}');

    try {
      final http.Response response = await http.get(
        getReferralByRefereeUri,
        headers: {'Content-Type': 'application/json'},
      );

      quantusDebugPrint('getReferralData response: ${response.body}');

      // If account doesn't have referrer, it will return 404 code.
      // Therefore we can confidently say it has been checked successfully.
      // We don't have to check it anymore.
      if (response.statusCode == 404) {
        _hasCheckedReferralData = true;
        return null;
      } else if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final referralData = ReferralData.fromJson(json);

      final referralCode = await _checksumService.getHumanReadableName(referralData.referrerAddress);
      _referralDataCache = referralCode;
      _hasCheckedReferralData = true;

      return referralCode;
    } catch (e) {
      return null;
    }
  }

  void invalidateCache() {
    _rewardProgramParticipationCache = null;
    _hasCheckedReferralData = false;
    _referralDataCache = null;
  }

  Future<bool> getRewardProgramParticiation() async {
    if (_rewardProgramParticipationCache != null) {
      return _rewardProgramParticipationCache!;
    }

    final hasOptedIn = await _taskmasterService.getRewardProgramParticipation();

    _rewardProgramParticipationCache = hasOptedIn;
    return hasOptedIn;
  }

  Future<void> submitReferralToBackend({required String referral}) async {
    await _taskmasterService.submitReferral(referral);
    _referralDataCache = referral;
  }

  Future<void> submitAddressToBackend() async {
    await _taskmasterService.submitAddress();
  }

  String generateReferralLink(String referralCode) {
    return '${AppConstants.websiteBaseUrl}/invite?referralCode=$referralCode';
  }

  Future<Account> getMainAccount() async {
    final account = await _taskmasterService.getMainAccount();
    return account;
  }

  Future<String> getMyInviteCode() async {
    final account = await getMainAccount();
    final referralCode = await _checksumService.getHumanReadableName(account.accountId);

    return referralCode;
  }

  Future<ShareParams> getShareLinkParameters(Rect? positionOrigin) async {
    final referralCode = await getMyInviteCode();

    String link = generateReferralLink(referralCode);
    String message =
        "Most L1s aren't ready for quantum threats. This one is.\nI'm on the @QuantusNetwork testnet stacking early points for rewards.\nUse my referral link so we both earn points:\n$referralCode\n\nDownload the wallet & get in early\n\n$link";

    return ShareParams(
      text: message,
      subject: 'Invite Link',
      title: 'Invite Link',
      sharePositionOrigin: positionOrigin,
    );
  }

  String? getReferralCode() {
    return _settingsService.getReferralCode();
  }
}
