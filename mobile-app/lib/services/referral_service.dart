import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/referral_data.dart';
import 'package:share_plus/share_plus.dart';

class ReferralService {
  final _mainAccountIndex = 0;
  final SettingsService _settingsService = SettingsService();
  final HumanReadableChecksumService _checksumService =
      HumanReadableChecksumService();
  final TaskmasterService _taskmasterService = TaskmasterService();

  Future<void> checkReferralOnInstall() async {
    // Only check once - on first launch after install
    bool hasChecked = _settingsService.referralCheckCompleted();
    if (hasChecked) return;

    try {
      ReferrerDetails referrerDetails =
          await PlayInstallReferrer.installReferrer;
      String? referrerString = referrerDetails.installReferrer;

      print('Raw Install Referrer: $referrerString');

      if (referrerString != null && referrerString.isNotEmpty) {
        Map<String, String> params = _parseReferrer(referrerString);

        String? referralCode = params['referral_code'];

        if (referralCode != null && referralCode.isNotEmpty) {
          SettingsService().setReferralCode(referralCode);
          SettingsService().setReferralCheckCompleted();
          print('Referral Code Found: $referralCode');
        }
      }

      print('No referral code found');
    } catch (e) {
      print('Error checking install referrer: $e');
    }
  }

  Future<void> optInRewardProgram() async {
    final account = await _settingsService.getAccount(_mainAccountIndex);
    if (account == null) {
      throw Exception(
        'Failed joining reward program, no active account detected!',
      );
    }
  }

  Map<String, String> _parseReferrer(String referrer) {
    Map<String, String> params = {};

    Uri uri = Uri.parse('?$referrer');
    params = Map.from(uri.queryParameters);

    return params;
  }

  Future<ReferralData?> getReferralData() async {
    final account = await _settingsService.getAccount(_mainAccountIndex);
    if (account == null) return null;

    final getReferralByRefereeUri = Uri.parse(
      '${AppConstants.taskMasterEndpoint}/referrals/${account.accountId}',
    );

    try {
      final http.Response response = await http.get(
        getReferralByRefereeUri,
        headers: {'Content-Type': 'application/json'},
      );

      print(response.body);
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ReferralData.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  Future<void> submitReferralToBackend({String? referral}) async {
    print('submitAddressToBackend $referral');

    bool hasSubmitRefferalCode = await getReferralData() != null;
    if (hasSubmitRefferalCode) return;

    final referralCode = referral ?? _settingsService.getReferralCode();
    final account1 = await _settingsService.getAccount(_mainAccountIndex);

    if (account1 == null) {
      throw Exception(
        'Failed sending referral to backend, no active account detected!',
      );
    }
    if (referralCode == null) {
      throw Exception(
        'Failed sending referral to backend, no referral code found!',
      );
    }

    await _taskmasterService.submitReferral(referralCode, account1);
  }

  Future<void> submitAddressToBackend(String address) async {
    await _taskmasterService.submitAddress(address);
  }

  String generateReferralLink(String referralCode) {
    return '${AppConstants.websiteBaseUrl}/invite?referralCode=$referralCode';
  }

  Future<ShareParams> getShareLinkParameters() async {
    final account = await _settingsService.getAccount(_mainAccountIndex);

    final referralCode = await _checksumService.getHumanReadableName(
      account!.accountId,
    );

    String link = generateReferralLink(referralCode);
    String message =
        'Join me on Quantus Wallet! Use my referral code: $referralCode\n\n$link';

    return ShareParams(
      text: message,
      subject: 'Invite Link',
      title: 'Invite Link',
    );
  }

  String? getReferralCode() {
    return _settingsService.getReferralCode();
  }
}
