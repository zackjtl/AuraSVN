import 'package:flutter/material.dart';
import 'dart:math' as math;

part 'aura_theme.g.dart';

final _appearanceThemeNotifier = ValueNotifier<String>('night');

const _cyberBackground = Color(0xFF050816);
const _cyberSurface = Color(0xE60B1226);
const _cyberSurfaceAlt = Color(0xFF111C36);
const _cyberSurfaceSoft = Color(0xFF17233F);
const _cyberAccent = Color(0xFF38BDF8);
const _cyberViolet = Color(0xFF8B5CF6);
const _cyberText = Color(0xFFE2E8F0);
const _cyberTextMuted = Color(0xFF94A3B8);
const _cyberTextSubtle = Color(0xFF64748B);
const _cyberBorder = Color(0xFF1E3A5F);

const _dayBackground = Color(0xFFF5F7FB);
const _daySurface = Color(0xF0FFFFFF);
const _daySurfaceAlt = Color(0xFFF8FAFC);
const _daySurfaceSoft = Color(0xFFEFF6FF);
const _dayAccent = Color(0xFF2563EB);
const _dayViolet = Color(0xFF7C3AED);
const _dayText = Color(0xFF0F172A);
const _dayTextMuted = Color(0xFF475569);
const _dayTextSubtle = Color(0xFF64748B);
const _dayBorder = Color(0xFFE2E8F0);

ThemeData _buildAuraThemeData(String appearanceThemeCode) {
  final night = _isNightAppearance(appearanceThemeCode);
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

  return ThemeData(
    brightness: night ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: colors.background,
    extensions: [colors],
    cardTheme: CardTheme(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.border),
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
    textTheme: base.textTheme.apply(
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
    dividerColor: colors.border,
  );
}

bool _isNightAppearance(String code) => code != 'day';

AuraThemeColors _aura(BuildContext context) {
  return Theme.of(context).extension<AuraThemeColors>() ??
      AuraThemeColors.night;
}

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
    background: _cyberBackground,
    surface: _cyberSurface,
    surfaceAlt: _cyberSurfaceAlt,
    surfaceSoft: _cyberSurfaceSoft,
    accent: _cyberAccent,
    violet: _cyberViolet,
    text: _cyberText,
    textMuted: _cyberTextMuted,
    textSubtle: _cyberTextSubtle,
    border: _cyberBorder,
  );

  static const day = AuraThemeColors(
    background: _dayBackground,
    surface: _daySurface,
    surfaceAlt: _daySurfaceAlt,
    surfaceSoft: _daySurfaceSoft,
    accent: _dayAccent,
    violet: _dayViolet,
    text: _dayText,
    textMuted: _dayTextMuted,
    textSubtle: _dayTextSubtle,
    border: _dayBorder,
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

class _CyberSpaceBackground extends StatefulWidget {
  const _CyberSpaceBackground();

  @override
  State<_CyberSpaceBackground> createState() => _CyberSpaceBackgroundState();
}

class _CyberSpaceBackgroundState extends State<_CyberSpaceBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _CyberSpacePainter(_controller.value),
        );
      },
    );
  }
}

class _DayAuraBackground extends StatelessWidget {
  const _DayAuraBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF6FF), Color(0xFFF8FAFC), Color(0xFFE0F2FE)],
        ),
      ),
    );
  }
}

class _CyberSpacePainter extends CustomPainter {
  const _CyberSpacePainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final background = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF020617),
          Color(0xFF06122A),
          Color(0xFF160C2D),
          Color(0xFF020617),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, background);

    _drawNebula(canvas, size);
    _drawGrid(canvas, size);
    _drawStars(canvas, size);
  }

  void _drawNebula(Canvas canvas, Size size) {
    final orbit = progress * math.pi * 2;
    final cyanCenter = Offset(
      size.width * (0.20 + math.sin(orbit) * 0.03),
      size.height * (0.18 + math.cos(orbit * 0.7) * 0.04),
    );
    final violetCenter = Offset(
      size.width * (0.78 + math.cos(orbit * 0.8) * 0.04),
      size.height * (0.72 + math.sin(orbit * 0.9) * 0.05),
    );
    for (final item in [
      (cyanCenter, _cyberAccent.withOpacity(0.28), size.shortestSide * 0.42),
      (violetCenter, _cyberViolet.withOpacity(0.24), size.shortestSide * 0.48),
    ]) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [item.$2, Colors.transparent],
        ).createShader(Rect.fromCircle(center: item.$1, radius: item.$3));
      canvas.drawCircle(item.$1, item.$3, paint);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _cyberAccent.withOpacity(0.065)
      ..strokeWidth = 1;
    const spacing = 56.0;
    final offset = progress * spacing;
    for (double x = -spacing + offset; x < size.width; x += spacing) {
      canvas.drawLine(
          Offset(x, 0), Offset(x + size.width * 0.18, size.height), paint);
    }
    for (double y = -spacing + offset; y < size.height; y += spacing) {
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y + size.height * 0.08), paint);
    }
  }

  void _drawStars(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.45);
    for (var i = 0; i < 70; i++) {
      final seed = i * 37.23;
      final x = ((math.sin(seed) * 0.5 + 0.5) * size.width);
      final baseY = ((math.cos(seed * 1.7) * 0.5 + 0.5) * size.height);
      final y = (baseY + progress * (18 + i % 9)) % size.height;
      final pulse = 0.55 + 0.45 * math.sin(progress * math.pi * 2 + i);
      canvas.drawCircle(Offset(x, y), 0.7 + pulse * 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberSpacePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
