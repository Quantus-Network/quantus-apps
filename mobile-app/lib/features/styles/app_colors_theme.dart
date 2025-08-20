import 'package:flutter/material.dart';

@immutable
class AppColorsTheme extends ThemeExtension<AppColorsTheme> {
  // I don't know about this two colors, it's already there since the beginning
  // Keep it for now since I'm no sure if it will break something if I remove it
  final Color primary;
  final Color secondary;

  // What we use
  final Color purple;
  final Color background;
  final Color surface;
  final Color surfaceActive;
  final Color error;
  final Color textPrimary;
  final Color textSecondary;
  final Color textError;
  final Color textMuted;
  final Color light;
  final Color circularLoader;
  final Color authButtonBg;
  final Color border;
  final Color borderLight;
  final Color buttonDisabled;
  final Color navbarBg;
  final Color checksum;
  final Color checksumDarker;
  final Color darkGray;

  const AppColorsTheme({
    required this.primary,
    required this.secondary,

    required this.purple,
    required this.background,
    required this.surface,
    required this.surfaceActive,
    required this.error,
    required this.textPrimary,
    required this.textSecondary,
    required this.textError,
    required this.light,
    required this.circularLoader,
    required this.authButtonBg,
    required this.textMuted,
    required this.border,
    required this.borderLight,
    required this.buttonDisabled,
    required this.navbarBg,
    required this.checksum,
    required this.checksumDarker,
    required this.darkGray,
  });

  const AppColorsTheme.light()
    : this(
        primary: const Color(0xFF6B46C1),
        secondary: const Color(0xFF9F7AEA),

        purple: const Color(0xFFB259F2),
        background: const Color(0xFF0E0E0E),
        surface: const Color(0xA6000000),
        surfaceActive: Colors.white,
        error: const Color(0xFFFF2D53),
        textError: const Color(0xFFFF5252),
        textPrimary: Colors.white,
        textSecondary: const Color(0xFF0F0F0F),
        light: const Color(0xFFE6E6E6),
        circularLoader: Colors.white,
        authButtonBg: const Color(0xFF16CECE),
        textMuted: const Color(0x99FFFFFF),
        border: const Color(0xcfe6e6e6),
        borderLight: const Color(0x26ffffff),
        buttonDisabled: const Color(0xFFE6E6E6),
        navbarBg: Colors.black,
        checksum: const Color(0xFF16CECE),
        checksumDarker: const Color(0xFF07A8A8),
        darkGray: const Color(0xFF323232),
      );

  const AppColorsTheme.dark()
    : this(
        primary: const Color(0xFF6B46C1),
        secondary: const Color(0xFF9F7AEA),

        purple: const Color(0xFFB259F2),
        background: const Color(0xFF0E0E0E),
        surface: const Color(0xA6000000),
        surfaceActive: Colors.white,
        error: const Color(0xFFFF2D53),
        textError: const Color(0xFFFF5252),
        textPrimary: Colors.white,
        textSecondary: const Color(0xFF0F0F0F),
        light: const Color(0xFFE6E6E6),
        circularLoader: Colors.white,
        authButtonBg: const Color(0xFF16CECE),
        textMuted: const Color(0x99FFFFFF),
        border: const Color(0xe6e6e6cf),
        borderLight: const Color(0x26ffffff),
        buttonDisabled: const Color(0xFFE6E6E6),
        navbarBg: Colors.black,
        checksum: const Color(0xFF16CECE),
        checksumDarker: const Color(0xFF07A8A8),
        darkGray: const Color(0xFF323232),
      );

  @override
  AppColorsTheme copyWith({
    Color? primary,
    Color? secondary,
    Color? purple,
    Color? background,
    Color? surface,
    Color? surfaceActive,
    Color? error,
    Color? textPrimary,
    Color? textSecondary,
    Color? textError,
    Color? light,
    Color? circularLoader,
    Color? authButtonBg,
    Color? textMuted,
    Color? border,
    Color? borderLight,
    Color? buttonDisabled,
    Color? navbarBg,
    Color? checksum,
    Color? checksumDarker,
    Color? darkGray,
  }) {
    return AppColorsTheme(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      purple: purple ?? this.purple,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceActive: surfaceActive ?? this.surfaceActive,
      error: error ?? this.error,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textError: textError ?? this.textError,
      light: light ?? this.light,
      circularLoader: circularLoader ?? this.circularLoader,
      authButtonBg: authButtonBg ?? this.authButtonBg,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      borderLight: borderLight ?? this.borderLight,
      buttonDisabled: buttonDisabled ?? this.buttonDisabled,
      navbarBg: navbarBg ?? this.navbarBg,
      checksum: checksum ?? this.checksum,
      checksumDarker: checksumDarker ?? this.checksumDarker,
      darkGray: darkGray ?? this.darkGray,
    );
  }

  @override
  AppColorsTheme lerp(AppColorsTheme? other, double t) {
    if (other is! AppColorsTheme) return this;
    return AppColorsTheme(
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      secondary: Color.lerp(secondary, other.secondary, t) ?? secondary,
      purple: Color.lerp(purple, other.purple, t) ?? purple,
      background: Color.lerp(background, other.background, t) ?? background,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceActive:
          Color.lerp(surfaceActive, other.surfaceActive, t) ?? surfaceActive,
      error: Color.lerp(error, other.error, t) ?? error,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textError: Color.lerp(textError, other.textError, t) ?? textError,
      light: Color.lerp(light, other.light, t) ?? light,
      circularLoader:
          Color.lerp(circularLoader, other.circularLoader, t) ?? circularLoader,
      authButtonBg:
          Color.lerp(authButtonBg, other.authButtonBg, t) ?? authButtonBg,
      textMuted: Color.lerp(textMuted, other.textMuted, t) ?? textMuted,
      border: Color.lerp(border, other.border, t) ?? border,
      borderLight: Color.lerp(borderLight, other.borderLight, t) ?? borderLight,
      buttonDisabled:
          Color.lerp(buttonDisabled, other.buttonDisabled, t) ?? buttonDisabled,
      navbarBg: Color.lerp(navbarBg, other.navbarBg, t) ?? navbarBg,
      checksum: Color.lerp(checksum, other.checksum, t) ?? checksum,
      checksumDarker:
          Color.lerp(checksumDarker, other.checksumDarker, t) ?? checksumDarker,
      darkGray: Color.lerp(darkGray, other.darkGray, t) ?? darkGray,
    );
  }
}

// Extension on BuildContext to access AppTextTheme styles directly
extension AppColorsThemeExtension on BuildContext {
  AppColorsTheme get themeColors => Theme.of(this).extension<AppColorsTheme>()!;
}
