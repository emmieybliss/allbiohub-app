import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Brand tokens that Material's ColorScheme doesn't cover.
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.gold,
    required this.onGold,
    required this.goldText,
    required this.goldSoft,
    required this.muted,
    required this.subtle,
    required this.card,
    required this.border,
    required this.skeleton,
    required this.skeletonHighlight,
    required this.verified,
    required this.heroScrim,
  });

  /// Brand gold for fills (buttons, badges).
  final Color gold;
  final Color onGold;

  /// Gold for text and icons on the page background; darker in light mode
  /// to keep WCAG AA contrast.
  final Color goldText;
  final Color goldSoft;
  final Color muted;
  final Color subtle;
  final Color card;
  final Color border;
  final Color skeleton;
  final Color skeletonHighlight;
  final Color verified;
  final Color heroScrim;

  static const light = BrandColors(
    gold: Color(0xFFC9A84C),
    onGold: Color(0xFF14110A),
    goldText: Color(0xFF7D5C12),
    goldSoft: Color(0xFFF3EAD3),
    muted: Color(0xFF5E574C),
    subtle: Color(0xFF8A8276),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFE7E1D6),
    skeleton: Color(0xFFECE7DE),
    skeletonHighlight: Color(0xFFF7F4EE),
    verified: Color(0xFF1F6FD1),
    heroScrim: Color(0xE6000000),
  );

  static const dark = BrandColors(
    gold: Color(0xFFD4B062),
    onGold: Color(0xFF14110A),
    goldText: Color(0xFFDDBD72),
    goldSoft: Color(0xFF2B2416),
    muted: Color(0xFFA9A39A),
    subtle: Color(0xFF7C776F),
    card: Color(0xFF17171B),
    border: Color(0xFF2A2A31),
    skeleton: Color(0xFF1F1F24),
    skeletonHighlight: Color(0xFF2A2A30),
    verified: Color(0xFF5EA2F0),
    heroScrim: Color(0xF2000000),
  );

  @override
  BrandColors copyWith() => this;

  @override
  BrandColors lerp(BrandColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return BrandColors(
      gold: l(gold, other.gold),
      onGold: l(onGold, other.onGold),
      goldText: l(goldText, other.goldText),
      goldSoft: l(goldSoft, other.goldSoft),
      muted: l(muted, other.muted),
      subtle: l(subtle, other.subtle),
      card: l(card, other.card),
      border: l(border, other.border),
      skeleton: l(skeleton, other.skeleton),
      skeletonHighlight: l(skeletonHighlight, other.skeletonHighlight),
      verified: l(verified, other.verified),
      heroScrim: l(heroScrim, other.heroScrim),
    );
  }
}

extension BrandTheme on BuildContext {
  BrandColors get brand => Theme.of(this).extension<BrandColors>()!;
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
}

abstract final class AppFonts {
  static const display = 'PlayfairDisplay';
  static const body = 'Inter';
}

/// Text style for the bundled variable fonts: sets the `wght` axis as well as
/// [FontWeight] so weights render correctly on every engine.
TextStyle fontStyle(
  String family,
  double size,
  FontWeight weight, {
  double? height,
  double? letterSpacing,
  Color? color,
}) => TextStyle(
  fontFamily: family,
  fontSize: size,
  fontWeight: weight,
  fontVariations: [FontVariation.weight(weight.value.toDouble())],
  height: height,
  letterSpacing: letterSpacing,
  color: color,
);

abstract final class AppTheme {
  static const _lightBackground = Color(0xFFF7F5F0);
  static const _darkBackground = Color(0xFF0B0B0D);

  static ThemeData light() => _build(
    brightness: Brightness.light,
    brand: BrandColors.light,
    scheme: const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF7D5C12),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFF3EAD3),
      onPrimaryContainer: Color(0xFF2B2006),
      secondary: Color(0xFF17140F),
      onSecondary: Colors.white,
      error: Color(0xFFB3261E),
      onError: Colors.white,
      surface: _lightBackground,
      onSurface: Color(0xFF17140F),
      onSurfaceVariant: Color(0xFF5E574C),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFFBFAF7),
      surfaceContainer: Color(0xFFF2EFE8),
      surfaceContainerHigh: Color(0xFFECE8DF),
      surfaceContainerHighest: Color(0xFFE6E1D7),
      outline: Color(0xFFD8D1C4),
      outlineVariant: Color(0xFFE7E1D6),
      inverseSurface: Color(0xFF17140F),
      onInverseSurface: Color(0xFFF7F5F0),
    ),
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    brand: BrandColors.dark,
    scheme: const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFDDBD72),
      onPrimary: Color(0xFF14110A),
      primaryContainer: Color(0xFF2B2416),
      onPrimaryContainer: Color(0xFFF3E3BC),
      secondary: Color(0xFFF2EFE9),
      onSecondary: Color(0xFF0B0B0D),
      error: Color(0xFFF2B8B5),
      onError: Color(0xFF601410),
      surface: _darkBackground,
      onSurface: Color(0xFFF2EFE9),
      onSurfaceVariant: Color(0xFFA9A39A),
      surfaceContainerLowest: Color(0xFF070708),
      surfaceContainerLow: Color(0xFF111114),
      surfaceContainer: Color(0xFF17171B),
      surfaceContainerHigh: Color(0xFF1F1F24),
      surfaceContainerHighest: Color(0xFF26262C),
      outline: Color(0xFF3A3A42),
      outlineVariant: Color(0xFF2A2A31),
      inverseSurface: Color(0xFFF2EFE9),
      onInverseSurface: Color(0xFF17140F),
    ),
  );

  static ThemeData _build({
    required Brightness brightness,
    required BrandColors brand,
    required ColorScheme scheme,
  }) {
    final textTheme = _textTheme(scheme.onSurface, brand.muted);
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: AppFonts.body,
      textTheme: textTheme,
      extensions: [brand],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: fontStyle(
          AppFonts.body,
          17,
          FontWeight.w600,
          color: scheme.onSurface,
        ),
        systemOverlayStyle:
            (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
                .copyWith(statusBarColor: Colors.transparent),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 66,
        backgroundColor: isDark ? const Color(0xFF111114) : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: brand.goldSoft,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => fontStyle(
            AppFonts.body,
            11.5,
            states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : brand.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? brand.goldText
                : brand.muted,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: brand.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: brand.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: brand.card,
        selectedColor: brand.goldSoft,
        side: BorderSide(color: brand.border),
        shape: const StadiumBorder(),
        labelStyle: fontStyle(
          AppFonts.body,
          13,
          FontWeight.w500,
          color: scheme.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        showCheckmark: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand.gold,
          foregroundColor: brand.onGold,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: fontStyle(AppFonts.body, 15, FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(64, 48),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: fontStyle(AppFonts.body, 15, FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: brand.goldText,
          minimumSize: const Size(48, 44),
          textStyle: fontStyle(AppFonts.body, 14, FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF17171B) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: fontStyle(
          AppFonts.body,
          15,
          FontWeight.w400,
          color: brand.subtle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: brand.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: brand.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: brand.goldText, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: brand.border,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: brand.muted,
        titleTextStyle: fontStyle(
          AppFonts.body,
          15.5,
          FontWeight.w500,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: fontStyle(
          AppFonts.body,
          13,
          FontWeight.w400,
          color: brand.muted,
        ),
        minVerticalPadding: 12,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? const Color(0xFF141417) : Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: fontStyle(
          AppFonts.body,
          14,
          FontWeight.w500,
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: brand.goldText),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme(Color text, Color muted) => TextTheme(
    displayLarge: fontStyle(
      AppFonts.display,
      40,
      FontWeight.w700,
      height: 1.1,
      color: text,
    ),
    displayMedium: fontStyle(
      AppFonts.display,
      34,
      FontWeight.w700,
      height: 1.12,
      color: text,
    ),
    displaySmall: fontStyle(
      AppFonts.display,
      30,
      FontWeight.w700,
      height: 1.15,
      color: text,
    ),
    headlineLarge: fontStyle(
      AppFonts.display,
      28,
      FontWeight.w700,
      height: 1.2,
      color: text,
    ),
    headlineMedium: fontStyle(
      AppFonts.display,
      24,
      FontWeight.w700,
      height: 1.22,
      color: text,
    ),
    headlineSmall: fontStyle(
      AppFonts.display,
      21,
      FontWeight.w700,
      height: 1.25,
      color: text,
    ),
    titleLarge: fontStyle(
      AppFonts.display,
      19,
      FontWeight.w700,
      height: 1.28,
      color: text,
    ),
    titleMedium: fontStyle(
      AppFonts.display,
      16.5,
      FontWeight.w600,
      height: 1.3,
      color: text,
    ),
    titleSmall: fontStyle(
      AppFonts.body,
      14,
      FontWeight.w600,
      height: 1.35,
      color: text,
    ),
    bodyLarge: fontStyle(
      AppFonts.body,
      16,
      FontWeight.w400,
      height: 1.6,
      color: text,
    ),
    bodyMedium: fontStyle(
      AppFonts.body,
      14,
      FontWeight.w400,
      height: 1.5,
      color: text,
    ),
    bodySmall: fontStyle(
      AppFonts.body,
      12.5,
      FontWeight.w400,
      height: 1.45,
      color: muted,
    ),
    labelLarge: fontStyle(
      AppFonts.body,
      14,
      FontWeight.w600,
      letterSpacing: 0.1,
      color: text,
    ),
    labelMedium: fontStyle(
      AppFonts.body,
      12,
      FontWeight.w600,
      letterSpacing: 0.4,
      color: muted,
    ),
    labelSmall: fontStyle(
      AppFonts.body,
      11,
      FontWeight.w700,
      letterSpacing: 1.2,
      color: muted,
    ),
  );
}
