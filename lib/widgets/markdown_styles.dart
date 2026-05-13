import 'package:aura_svn/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

MarkdownStyleSheet auraMarkdownStyle(BuildContext context) {
  final theme = Theme.of(context);
  final colors = aura(context);
  // 與內文共用同一套 fontFamily，避免 strong 只用 fontWeight.bold 變成偽粗體（Windows 上易暈開）
  final body = theme.textTheme.bodyMedium?.copyWith(
        color: colors.text,
        height: 1.55,
      ) ??
      TextStyle(color: colors.text, height: 1.55, fontSize: 14);
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    h1: theme.textTheme.headlineSmall?.copyWith(
      color: colors.text,
      fontWeight: FontWeight.w600,
    ),
    h2: theme.textTheme.titleLarge?.copyWith(
      color: colors.text,
      fontWeight: FontWeight.w600,
    ),
    h3: theme.textTheme.titleMedium?.copyWith(
      color: colors.text,
      fontWeight: FontWeight.w600,
    ),
    p: body,
    strong: body.copyWith(fontWeight: FontWeight.w600),
    em: body.copyWith(fontStyle: FontStyle.italic),
    listBullet: body.copyWith(color: colors.accent),
    code: TextStyle(
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF7DD3FC)
          : const Color(0xFF0369A1),
      fontFamily: 'monospace',
      fontSize: 13,
      backgroundColor: colors.surfaceSoft,
    ),
    codeblockDecoration: BoxDecoration(
      color: colors.surfaceSoft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: colors.border),
    ),
    codeblockPadding: const EdgeInsets.all(14),
    blockquote: body.copyWith(color: colors.textMuted),
    blockquoteDecoration: BoxDecoration(
      color: colors.surfaceSoft,
      borderRadius: BorderRadius.circular(12),
      border: Border(left: BorderSide(color: colors.accent, width: 4)),
    ),
    tableHead: body.copyWith(
      color: colors.text,
      fontWeight: FontWeight.w600,
    ),
    tableBody: body,
    tableBorder: TableBorder.all(color: colors.border),
    a: TextStyle(
      color: colors.accent,
      decoration: TextDecoration.underline,
    ),
  );
}
