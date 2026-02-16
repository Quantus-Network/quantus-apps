import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/copy_icon.dart';
import 'package:resonance_network_wallet/features/components/inner_shadow_container.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/quest_constants.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_associations_providers.dart';
import 'package:resonance_network_wallet/providers/account_stats_providers.dart';
import 'package:resonance_network_wallet/services/referral_service.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:share_plus/share_plus.dart';

class ReferralsQuestScreen extends ConsumerStatefulWidget {
  const ReferralsQuestScreen({super.key});

  @override
  ConsumerState<ReferralsQuestScreen> createState() => _ReferralsQuestScreenState();
}

class _ReferralsQuestScreenState extends ConsumerState<ReferralsQuestScreen> {
  final ReferralService _referralService = ReferralService();
  final TaskmasterService _taskmasterService = TaskmasterService();
  String? _referralCode;
  int? _rank;

  Future<void> _loadReferralCode() async {
    try {
      final myReferralCode = await _referralService.getMyInviteCode();
      setState(() {
        _referralCode = myReferralCode;
      });
      _loadRank(myReferralCode);
    } catch (e) {
      debugPrint('Error loading referral code: $e');
    }
  }

  Future<void> _loadRank(String referralCode) async {
    try {
      final rankData = await _taskmasterService.getReferralRank(referralCode);
      if (mounted) {
        setState(() {
          _rank = rankData.rank;
        });
      }
    } catch (e) {
      debugPrint('Error loading rank: $e');
    }
  }

  Future<void> _shareReferralLink() async {
    final params = await _referralService.getShareLinkParameters(context.sharePositionRect());
    SharePlus.instance.share(params);
  }

  void _copyReferralCode() {
    if (_referralCode != null) {
      context.copyTextWithToaster(_referralCode!, message: 'Referral code copied to clipboard');
    }
  }

  void _showHowItWorksDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(24),
                decoration: ShapeDecoration(
                  color: context.themeColors.background2,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(width: 1, color: Color(0x66F4F6F9)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('HOW IT WORKS', style: context.themeText.paragraph),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Icon(Icons.close, color: Colors.white, size: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildStep('Step 1', 'Invite users using your unique code'),
                    const SizedBox(height: 16),
                    _buildStep(
                      'Step 2',
                      'They must create a Quantus Wallet. Referrals without wallet creation won\'t count',
                    ),
                    const SizedBox(height: 16),
                    _buildStep('Step 3', 'Climb the leaderboard. Rank updates automatically'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'Fira Code',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          description,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.50),
            fontSize: 14,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadReferralCode();
  }

  void refreshStatsData() {
    ref.invalidate(accountsStatsProvider);
    ref.invalidate(accountAssociationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(accountsStatsProvider);
    final referralsCount = statsAsync.value?.referralCount;

    return ScaffoldBase(
      appBar: WalletAppBar(
        title: 'Referrals',
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showHowItWorksDialog,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  color: context.themeColors.background2,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(width: 1, color: Color(0x7F6734BA)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: InnerShadowContainer.standard(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        left: -156,
                        top: 72,
                        child: Container(
                          width: 531,
                          height: 531,
                          clipBehavior: Clip.antiAlias,
                          decoration: ShapeDecoration(
                            gradient: const RadialGradient(
                              center: Alignment(0.77, -0.77),
                              radius: 1.8,
                              colors: questReferFriendsGradient,
                              stops: [0.45, 0.53, 0.62, 0.65],
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  Text('REFER FRIENDS', style: context.themeText.paragraph),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Invite friends. Earn rewards. \nClimb the leaderboard.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.50),
                                      fontSize: 14,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // these colors aren't really great anyway..should be spheres for accounts..
                                _buildAvatar([const Color(0xFF0000FF), context.themeColors.background2]),
                                Transform.translate(
                                  offset: const Offset(-16, 0),
                                  child: _buildAvatar([const Color(0xFF8B0000), context.themeColors.pink]),
                                ),
                                Transform.translate(
                                  offset: const Offset(-32, 0),
                                  child: _buildAvatar([const Color(0xFFFFD700), context.themeColors.yellow]),
                                ),
                              ],
                            ),
                            const SizedBox(height: 40),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: ShapeDecoration(
                                color: context.themeColors.background2.useOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  side: const BorderSide(width: 1, color: Color(0x33F4F6F9)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                shadows: const [
                                  BoxShadow(color: Color(0x3F000000), blurRadius: 4, offset: Offset(4, 4)),
                                ],
                              ),
                              child: Column(
                                children: [
                                  _buildStatRow('Referrals', _buildLoadingOrValue(referralsCount, Colors.white)),
                                  const SizedBox(height: 16),
                                  _buildStatRow(
                                    'Rank',
                                    _buildLoadingOrValue(_rank, context.themeColors.pink, isRank: true),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'Your invite code',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontFamily: 'Fira Code',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                GestureDetector(
                                  onTap: _copyReferralCode,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: ShapeDecoration(
                                      color: Colors.white.useOpacity(0.3),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _referralCode ?? 'Loading...',
                                          style: const TextStyle(
                                            color: Color(0xFFF4F6F9),
                                            fontSize: 12,
                                            fontFamily: 'Fira Code',
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                        const CopyIcon(width: 16, color: Color(0xFFF4F6F9)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _shareReferralLink,
              child: InnerShadowContainer.standard(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: ShapeDecoration(
                    color: const Color(0x33F4F6F9),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(width: 1, color: Color(0x33F4F6F9)),
                      borderRadius: BorderRadius.circular(42),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Share Link',
                    style: context.themeText.smallTitle?.copyWith(color: context.themeColors.textPrimary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(List<Color> colors) {
    return Container(
      width: 64,
      height: 64,
      decoration: ShapeDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
        shape: OvalBorder(
          side: BorderSide(
            width: 2.67,
            strokeAlign: BorderSide.strokeAlignOutside,
            color: context.themeColors.background2,
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, Widget valueWidget) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFF4F6F9),
            fontSize: 14,
            fontFamily: 'Fira Code',
            fontWeight: FontWeight.w400,
          ),
        ),
        valueWidget,
      ],
    );
  }

  Widget _buildLoadingOrValue(int? value, Color color, {bool isRank = false}) {
    if (value == null) {
      return SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: color));
    }
    final text = isRank ? (value > 0 ? '#$value' : '#-') : '$value';
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: color, fontSize: 14, fontFamily: 'Fira Code', fontWeight: FontWeight.w400),
    );
  }
}
