import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 夜晚：全畫布基底色（使用者指定）
const cyberBase = Color(0xFF0A1125);
/// 夜晚：主內容欄（比基底色更深）
const cyberMainPanel = Color(0xFF050A16);
/// 夜晚：左側控制欄（比基底色略淺）
const cyberSidebar = Color(0xFF131F38);
/// 夜晚：與側欄同階的 surface（分支列、玻璃底等）
const cyberSurface = cyberSidebar;
/// 夜晚：卡片／區塊略抬升的底色
const cyberSurfaceAlt = Color(0xFF0E172B);
const cyberSurfaceSoft = Color(0xFF0A1324);
const cyberAccent = Color(0xFF00DBE7);
const cyberViolet = Color(0xFFEBB2FF);
const cyberText = Color(0xFFDCE4E4);
const cyberTextMuted = Color(0xFFB9CACB);
const cyberTextSubtle = Color(0xFF849495);
/// 夜晚：卡片與區塊邊線（使用者指定）
const cyberBorder = Color(0xFF1E3A5F);

/// 舊名相容：多處用 `cyberBackground` 當全畫布底
const cyberBackground = cyberBase;

const dayBackground = Color(0xFFF5F7FB);
const daySurface = Color(0xF0FFFFFF);
const daySurfaceAlt = Color(0xFFF8FAFC);
const daySurfaceSoft = Color(0xFFEFF6FF);
const dayAccent = Color(0xFF2563EB);
const dayViolet = Color(0xFF7C3AED);
const dayText = Color(0xFF0F172A);
const dayTextMuted = Color(0xFF475569);
const dayTextSubtle = Color(0xFF64748B);
const dayBorder = Color(0xFFE2E8F0);

/// code.html (Stitch) — 對齊新夜晚藍調
const stitchSurfaceContainerHigh = cyberSidebar;
const stitchSurfaceDim = cyberMainPanel;
const stitchPrimaryFixed = Color(0xFF74F5FF);
const stitchGlassFill = cyberMainPanel;
const stitchGlassBorder = Color(0x1AFFFFFF);

/// 頂部儀表條左邊框強調色（Commits → Nodes → Backend → Author）
const metricStripLeftCommits = Color(0xFF836A91);
const metricStripLeftNodes = Color(0xFF71EEF8);
const metricStripLeftBackend = Color(0xFFFFB86B);
const metricStripLeftAuthor = Color(0xFFFF6B9D);

final appearanceThemeNotifier = ValueNotifier<String>('night');

bool isNightAppearance(String code) => code != 'day';

class AuraThemeColors extends ThemeExtension<AuraThemeColors> {
  const AuraThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSoft,
    required this.accent,
    required this.violet,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.border,
  });

  static const night = AuraThemeColors(
    background: cyberBase,
    surface: cyberSurface,
    surfaceAlt: cyberSurfaceAlt,
    surfaceSoft: cyberSurfaceSoft,
    accent: cyberAccent,
    violet: cyberViolet,
    text: cyberText,
    textMuted: cyberTextMuted,
    textSubtle: cyberTextSubtle,
    border: cyberBorder,
  );

  static const day = AuraThemeColors(
    background: dayBackground,
    surface: daySurface,
    surfaceAlt: daySurfaceAlt,
    surfaceSoft: daySurfaceSoft,
    accent: dayAccent,
    violet: dayViolet,
    text: dayText,
    textMuted: dayTextMuted,
    textSubtle: dayTextSubtle,
    border: dayBorder,
  );

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceSoft;
  final Color accent;
  final Color violet;
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color border;

  @override
  AuraThemeColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceSoft,
    Color? accent,
    Color? violet,
    Color? text,
    Color? textMuted,
    Color? textSubtle,
    Color? border,
  }) {
    return AuraThemeColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      accent: accent ?? this.accent,
      violet: violet ?? this.violet,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textSubtle: textSubtle ?? this.textSubtle,
      border: border ?? this.border,
    );
  }

  @override
  AuraThemeColors lerp(ThemeExtension<AuraThemeColors>? other, double t) {
    if (other is! AuraThemeColors) {
      return this;
    }
    return AuraThemeColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      violet: Color.lerp(violet, other.violet, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSubtle: Color.lerp(textSubtle, other.textSubtle, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

AuraThemeColors aura(BuildContext context) {
  return Theme.of(context).extension<AuraThemeColors>() ??
      AuraThemeColors.night;
}

ThemeData buildAuraThemeData(String appearanceThemeCode) {
  final night = isNightAppearance(appearanceThemeCode);
  final colors = night ? AuraThemeColors.night : AuraThemeColors.day;
  final scheme = ColorScheme.fromSeed(
    seedColor: colors.accent,
    brightness: night ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: colors.accent,
    secondary: colors.violet,
    surface: colors.surfaceAlt,
    onSurface: colors.text,
    outline: colors.border,
  );
  final base = night ? ThemeData.dark() : ThemeData.light();
  final baseTextTheme =
      night ? GoogleFonts.interTextTheme(base.textTheme) : base.textTheme;

  return ThemeData(
    brightness: night ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: colors.background,
    extensions: [colors],
    cardTheme: CardTheme(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: night ? colors.surfaceAlt : colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(night ? 8 : 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.accent),
      ),
      labelStyle: TextStyle(color: colors.textMuted),
      hintStyle: TextStyle(color: colors.textSubtle),
      prefixIconColor: colors.textMuted,
    ),
    textTheme: baseTextTheme.apply(
      bodyColor: colors.text,
      displayColor: colors.text,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surfaceSoft,
      selectedColor: colors.accent.withOpacity(night ? 0.2 : 0.14),
      side: BorderSide(color: colors.border),
      labelStyle: TextStyle(color: colors.text),
      secondaryLabelStyle: TextStyle(color: colors.text),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colors.accent.withOpacity(night ? 0.16 : 0.12);
          }
          return Colors.transparent;
        }),
        foregroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colors.accent;
          }
          return colors.textMuted;
        }),
        iconColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colors.accent;
          }
          return colors.textMuted;
        }),
        side: MaterialStateProperty.all(BorderSide(color: colors.border)),
      ),
    ),
    dividerColor: colors.border,
  );
}
