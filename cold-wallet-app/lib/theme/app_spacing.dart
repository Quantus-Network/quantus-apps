import 'package:flutter/material.dart';

@immutable
class AppSizeTheme extends ThemeExtension<AppSizeTheme> {
  final double logoHeight;
  final double mainMenuHeight;
  final double mainMenuWidth;
  final double mainMenuIconSize;
  final double navbarHeight;
  final double navbarItemHeight;
  final double navbarItemWidth;
  final double navbarIconWidth;
  final double floatingBtnHeight;
  final double floatingBtnWidth;
  final double settingMenuIconSize;
  final double settingMenuShareIconSize;
  final double accountListItemHeight;
  final double accountListItemLogoWidth;
  final double appbarIconSize;
  final double sendOverlayContainerWidth;
  final double overlayCloseIconSize;
  final double mnemonicCellDesiredHeight;
  final double txListItemIconWidth;
  final double txDetailsIconHeight;
  final double txDetailsIconWidth;
  final double copyIconSize;
  final double pasteIconSize;
  final double timePickerSubtitleWidth;
  final double bottomButtonSpacing;
  final double buttonsHorizontalSpacing;
  final double infoSheetTitleIcon;

  final double screenPadding;
  final double cardPadding;
  final double sectionGap;
  final double itemGap;
  final double sectionHeaderToContent;

  final double radiusFull;
  final double radiusCard;
  final double radiusSmall;

  const AppSizeTheme({
    required this.logoHeight,
    required this.mainMenuHeight,
    required this.mainMenuWidth,
    required this.mainMenuIconSize,
    required this.navbarHeight,
    required this.navbarItemHeight,
    required this.navbarItemWidth,
    required this.navbarIconWidth,
    required this.floatingBtnHeight,
    required this.floatingBtnWidth,
    required this.settingMenuIconSize,
    required this.settingMenuShareIconSize,
    required this.accountListItemHeight,
    required this.accountListItemLogoWidth,
    required this.appbarIconSize,
    required this.sendOverlayContainerWidth,
    required this.overlayCloseIconSize,
    required this.mnemonicCellDesiredHeight,
    required this.txListItemIconWidth,
    required this.txDetailsIconHeight,
    required this.txDetailsIconWidth,
    required this.copyIconSize,
    required this.pasteIconSize,
    required this.timePickerSubtitleWidth,
    required this.bottomButtonSpacing,
    required this.buttonsHorizontalSpacing,
    required this.infoSheetTitleIcon,
    required this.screenPadding,
    required this.cardPadding,
    required this.sectionGap,
    required this.itemGap,
    required this.sectionHeaderToContent,
    required this.radiusFull,
    required this.radiusCard,
    required this.radiusSmall,
  });

  const AppSizeTheme.defaultTheme()
    : this(
        logoHeight: 158.0,
        mainMenuHeight: 20,
        mainMenuWidth: 20,
        mainMenuIconSize: 21.0,
        navbarHeight: 67.0,
        navbarItemHeight: 32,
        navbarItemWidth: 40,
        navbarIconWidth: 23,
        floatingBtnHeight: 49.0,
        floatingBtnWidth: 52.0,
        settingMenuIconSize: 11.0,
        settingMenuShareIconSize: 20.0,
        accountListItemHeight: 110.0,
        accountListItemLogoWidth: 36.0,
        appbarIconSize: 18.0,
        sendOverlayContainerWidth: double.infinity,
        overlayCloseIconSize: 24.0,
        mnemonicCellDesiredHeight: 31.0,
        txListItemIconWidth: 21.0,
        txDetailsIconHeight: 43.0,
        txDetailsIconWidth: 51.0,
        copyIconSize: 20.0,
        pasteIconSize: 18.0,
        timePickerSubtitleWidth: 249,
        bottomButtonSpacing: 16,
        buttonsHorizontalSpacing: 28,
        infoSheetTitleIcon: 25,
        screenPadding: 24.0,
        cardPadding: 20.0,
        sectionGap: 40.0,
        itemGap: 12.0,
        sectionHeaderToContent: 36.0,
        radiusFull: 30.0,
        radiusCard: 14.0,
        radiusSmall: 6.0,
      );

  const AppSizeTheme.iPad()
    : this(
        logoHeight: 180.0,
        mainMenuHeight: 30,
        mainMenuWidth: 30,
        mainMenuIconSize: 29.0,
        navbarHeight: 87.0,
        navbarItemHeight: 40,
        navbarItemWidth: 48,
        navbarIconWidth: 32,
        floatingBtnHeight: 74.0,
        floatingBtnWidth: 77.0,
        settingMenuIconSize: 16.0,
        settingMenuShareIconSize: 24.0,
        accountListItemHeight: 130.0,
        accountListItemLogoWidth: 48.0,
        appbarIconSize: 20.0,
        sendOverlayContainerWidth: 510.0,
        overlayCloseIconSize: 28.0,
        mnemonicCellDesiredHeight: 80.0,
        txListItemIconWidth: 32.0,
        txDetailsIconHeight: 82.0,
        txDetailsIconWidth: 91.0,
        copyIconSize: 28.0,
        pasteIconSize: 24.0,
        timePickerSubtitleWidth: 400,
        bottomButtonSpacing: 16,
        buttonsHorizontalSpacing: 28,
        infoSheetTitleIcon: 28,
        screenPadding: 32.0,
        cardPadding: 24.0,
        sectionGap: 48.0,
        itemGap: 16.0,
        sectionHeaderToContent: 40.0,
        radiusFull: 30.0,
        radiusCard: 14.0,
        radiusSmall: 6.0,
      );

  @override
  AppSizeTheme copyWith({
    double? logoHeight,
    double? mainMenuHeight,
    double? mainMenuWidth,
    double? mainMenuIconSize,
    double? navbarHeight,
    double? navbarItemHeight,
    double? navbarItemWidth,
    double? navbarIconWidth,
    double? floatingBtnHeight,
    double? floatingBtnWidth,
    double? settingMenuIconSize,
    double? settingMenuShareIconSize,
    double? accountListItemHeight,
    double? accountListItemLogoWidth,
    double? appbarIconSize,
    double? sendOverlayContainerWidth,
    double? overlayCloseIconSize,
    double? mnemonicCellDesiredHeight,
    double? txListItemIconWidth,
    double? txDetailsIconHeight,
    double? txDetailsIconWidth,
    double? copyIconSize,
    double? pasteIconSize,
    double? timePickerSubtitleWidth,
    double? bottomButtonSpacing,
    double? buttonsHorizontalSpacing,
    double? infoSheetTitleIcon,
    double? screenPadding,
    double? cardPadding,
    double? sectionGap,
    double? itemGap,
    double? sectionHeaderToContent,
    double? radiusFull,
    double? radiusCard,
    double? radiusSmall,
  }) {
    return AppSizeTheme(
      logoHeight: logoHeight ?? this.logoHeight,
      mainMenuHeight: mainMenuHeight ?? this.mainMenuHeight,
      mainMenuWidth: mainMenuWidth ?? this.mainMenuWidth,
      mainMenuIconSize: mainMenuIconSize ?? this.mainMenuIconSize,
      navbarHeight: navbarHeight ?? this.navbarHeight,
      navbarItemHeight: navbarItemHeight ?? this.navbarItemHeight,
      navbarItemWidth: navbarItemWidth ?? this.navbarItemWidth,
      navbarIconWidth: navbarIconWidth ?? this.navbarIconWidth,
      floatingBtnHeight: floatingBtnHeight ?? this.floatingBtnHeight,
      floatingBtnWidth: floatingBtnWidth ?? this.floatingBtnWidth,
      settingMenuIconSize: settingMenuIconSize ?? this.settingMenuIconSize,
      settingMenuShareIconSize: settingMenuShareIconSize ?? this.settingMenuShareIconSize,
      accountListItemHeight: accountListItemHeight ?? this.accountListItemHeight,
      accountListItemLogoWidth: accountListItemLogoWidth ?? this.accountListItemLogoWidth,
      appbarIconSize: appbarIconSize ?? this.appbarIconSize,
      sendOverlayContainerWidth: sendOverlayContainerWidth ?? this.sendOverlayContainerWidth,
      overlayCloseIconSize: overlayCloseIconSize ?? this.overlayCloseIconSize,
      mnemonicCellDesiredHeight: mnemonicCellDesiredHeight ?? this.mnemonicCellDesiredHeight,
      txListItemIconWidth: txListItemIconWidth ?? this.txListItemIconWidth,
      txDetailsIconHeight: txDetailsIconHeight ?? this.txDetailsIconHeight,
      txDetailsIconWidth: txDetailsIconWidth ?? this.txDetailsIconWidth,
      copyIconSize: copyIconSize ?? this.copyIconSize,
      pasteIconSize: pasteIconSize ?? this.pasteIconSize,
      timePickerSubtitleWidth: timePickerSubtitleWidth ?? this.timePickerSubtitleWidth,
      bottomButtonSpacing: bottomButtonSpacing ?? this.bottomButtonSpacing,
      buttonsHorizontalSpacing: buttonsHorizontalSpacing ?? this.buttonsHorizontalSpacing,
      infoSheetTitleIcon: infoSheetTitleIcon ?? this.infoSheetTitleIcon,
      screenPadding: screenPadding ?? this.screenPadding,
      cardPadding: cardPadding ?? this.cardPadding,
      sectionGap: sectionGap ?? this.sectionGap,
      itemGap: itemGap ?? this.itemGap,
      sectionHeaderToContent: sectionHeaderToContent ?? this.sectionHeaderToContent,
      radiusFull: radiusFull ?? this.radiusFull,
      radiusCard: radiusCard ?? this.radiusCard,
      radiusSmall: radiusSmall ?? this.radiusSmall,
    );
  }

  @override
  AppSizeTheme lerp(AppSizeTheme? other, double t) {
    if (other is! AppSizeTheme) return this;
    double l(double a, double b) => a + (b - a) * t;
    return AppSizeTheme(
      logoHeight: l(logoHeight, other.logoHeight),
      mainMenuHeight: l(mainMenuHeight, other.mainMenuHeight),
      mainMenuWidth: l(mainMenuWidth, other.mainMenuWidth),
      mainMenuIconSize: l(mainMenuIconSize, other.mainMenuIconSize),
      navbarHeight: l(navbarHeight, other.navbarHeight),
      navbarItemHeight: l(navbarItemHeight, other.navbarItemHeight),
      navbarItemWidth: l(navbarItemWidth, other.navbarItemWidth),
      navbarIconWidth: l(navbarIconWidth, other.navbarIconWidth),
      floatingBtnHeight: l(floatingBtnHeight, other.floatingBtnHeight),
      floatingBtnWidth: l(floatingBtnWidth, other.floatingBtnWidth),
      settingMenuIconSize: l(settingMenuIconSize, other.settingMenuIconSize),
      settingMenuShareIconSize: l(settingMenuShareIconSize, other.settingMenuShareIconSize),
      accountListItemHeight: l(accountListItemHeight, other.accountListItemHeight),
      accountListItemLogoWidth: l(accountListItemLogoWidth, other.accountListItemLogoWidth),
      appbarIconSize: l(appbarIconSize, other.appbarIconSize),
      sendOverlayContainerWidth: l(sendOverlayContainerWidth, other.sendOverlayContainerWidth),
      overlayCloseIconSize: l(overlayCloseIconSize, other.overlayCloseIconSize),
      mnemonicCellDesiredHeight: l(mnemonicCellDesiredHeight, other.mnemonicCellDesiredHeight),
      txListItemIconWidth: l(txListItemIconWidth, other.txListItemIconWidth),
      txDetailsIconHeight: l(txDetailsIconHeight, other.txDetailsIconHeight),
      txDetailsIconWidth: l(txDetailsIconWidth, other.txDetailsIconWidth),
      copyIconSize: l(copyIconSize, other.copyIconSize),
      pasteIconSize: l(pasteIconSize, other.pasteIconSize),
      timePickerSubtitleWidth: l(timePickerSubtitleWidth, other.timePickerSubtitleWidth),
      bottomButtonSpacing: l(bottomButtonSpacing, other.bottomButtonSpacing),
      buttonsHorizontalSpacing: l(buttonsHorizontalSpacing, other.buttonsHorizontalSpacing),
      infoSheetTitleIcon: l(infoSheetTitleIcon, other.infoSheetTitleIcon),
      screenPadding: l(screenPadding, other.screenPadding),
      cardPadding: l(cardPadding, other.cardPadding),
      sectionGap: l(sectionGap, other.sectionGap),
      itemGap: l(itemGap, other.itemGap),
      sectionHeaderToContent: l(sectionHeaderToContent, other.sectionHeaderToContent),
      radiusFull: l(radiusFull, other.radiusFull),
      radiusCard: l(radiusCard, other.radiusCard),
      radiusSmall: l(radiusSmall, other.radiusSmall),
    );
  }
}

extension AppSizeThemeExtension on BuildContext {
  AppSizeTheme get themeSize => Theme.of(this).extension<AppSizeTheme>()!;
}
