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

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(t(context, '返回', 'Back')),
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
