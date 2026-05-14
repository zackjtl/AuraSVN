import 'package:aura_svn/app_theme.dart';
import 'package:aura_svn/language_scope.dart';
import 'package:flutter/material.dart';

/// 無邊框、無底色包覆的頂列：橢圓淺色「← 返回」與標題／副標題垂直置中對齊，右側可選 [trailing]。
class AuraBackPageHeader extends StatelessWidget {
  const AuraBackPageHeader({
    super.key,
    required this.onBack,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
  });

  final VoidCallback onBack;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = aura(context);
    final isDark = theme.brightness == Brightness.dark;

    final pillBg = isDark
        ? const Color(0xFFE2E8F0).withOpacity(0.9)
        : Color.alphaBlend(Colors.white.withOpacity(0.92), a.surfaceSoft);
    final pillFg = isDark ? const Color(0xFF0F172A) : a.text;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Tooltip(
            message: t(context, '返回主頁', 'Back to Home'),
            child: Material(
              color: pillBg,
              borderRadius: BorderRadius.circular(999),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onBack,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 18, color: pillFg),
                      const SizedBox(width: 6),
                      Text(
                        t(context, '返回', 'Return'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: pillFg,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: isDark ? stitchPrimaryFixed : a.text,
                  ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: a.textMuted,
                      height: 1.35,
                    ),
                  ),
                ],
                if (subtitleWidget != null) ...[
                  const SizedBox(height: 4),
                  subtitleWidget!,
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
