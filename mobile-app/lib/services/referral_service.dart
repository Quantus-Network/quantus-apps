import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/referral_data.dart';
import 'package:share_plus/share_plus.dart';

class ReferralService {
  final SettingsService _settingsService = SettingsService();
  final HumanReadableChecksumService _checksumService =
      HumanReadableChecksumService();
  final TaskmasterService _taskmasterService = TaskmasterService();

  // This fetches any available referral code from the google play store and stores
  // it in settings if found.
  Future<void> checkPlayStoreReferralCode() async {
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
    final account = await getMainAccount();

    await _taskmasterService.optInRewardProgram(account);
  }

  Map<String, String> _parseReferrer(String referrer) {
    Map<String, String> params = {};

    Uri uri = Uri.parse('?$referrer');
    params = Map.from(uri.queryParameters);

    return params;
  }

  Future<ReferralData?> getReferralData() async {
    final account = await getMainAccount();

    final getReferralByRefereeUri = Uri.parse(
      '${AppConstants.taskMasterEndpoint}/referrals/${account.accountId}',
    );

    try {
      final http.Response response = await http.get(
        getReferralByRefereeUri,
        headers: {'Content-Type': 'application/json'},
      );

      print('getReferralData response: ${response.body}');

      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ReferralData.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  Future<bool> getRewardProgramParticiation() async {
    final hasOptedIn = await _taskmasterService.getRewardProgramParticipation();
    return hasOptedIn;
  }

  Future<void> submitReferralToBackend({required String referral}) async {
    await _taskmasterService.submitReferral(referral);
  }

  Future<void> submitAddressToBackend(String address) async {
    await _taskmasterService.submitAddress(address);
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
    final referralCode = await _checksumService.getHumanReadableName(
      account.accountId,
    );

    return referralCode;
  }

  Future<ShareParams> getShareLinkParameters() async {
    final referralCode = await getMyInviteCode();

    String link = generateReferralLink(referralCode);
    String message =
        'Join me on Quantum Future! Use my referral link so we both earn points: \n$link';

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
