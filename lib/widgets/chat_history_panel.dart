import 'package:aura_svn/app_theme.dart';
import 'package:aura_svn/chat_history_store.dart';
import 'package:aura_svn/language_scope.dart';
import 'package:aura_svn/models/chat_session.dart';
import 'package:flutter/material.dart';

/// Shows the chat history list in a dialog.
/// Returns the [ChatSession] the user wants to restore, or null if dismissed.
Future<ChatSession?> showChatHistoryDialog({
  required BuildContext context,
  required String notesRootPath,
  required String repoName,
}) {
  return showDialog<ChatSession>(
    context: context,
    builder: (_) => _ChatHistoryDialog(
      notesRootPath: notesRootPath,
      repoName: repoName,
    ),
  );
}

class _ChatHistoryDialog extends StatefulWidget {
  const _ChatHistoryDialog({
    required this.notesRootPath,
    required this.repoName,
  });

  final String notesRootPath;
  final String repoName;

  @override
  State<_ChatHistoryDialog> createState() => _ChatHistoryDialogState();
}

class _ChatHistoryDialogState extends State<_ChatHistoryDialog> {
  List<ChatSession>? _sessions;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await ChatHistoryStore.list(
        widget.notesRootPath, widget.repoName);
    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  Future<void> _delete(ChatSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t(ctx, '刪除對話記錄', 'Delete Session')),
        content: Text(t(ctx, '確定要刪除「${session.title}」嗎？',
            'Delete "${session.title}"?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t(ctx, '取消', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t(ctx, '刪除', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ChatHistoryStore.delete(session, widget.notesRootPath);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = aura(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? cyberBase : theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.history_rounded, size: 20, color: a.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t(context, '對話歷史記錄', 'Chat History'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? stitchPrimaryFixed : a.text,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                    color: a.textMuted,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
              child: Text(
                widget.repoName,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: a.textMuted),
              ),
            ),
            const Divider(height: 1),
            // Body
            Flexible(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _sessions == null || _sessions!.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              t(context, '尚無對話記錄', 'No sessions saved yet'),
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: a.textMuted),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _sessions!.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 16, endIndent: 16),
                          itemBuilder: (ctx, i) {
                            final s = _sessions![i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 4),
                              leading: Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 20,
                                color: a.accent,
                              ),
                              title: Text(
                                s.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color:
                                      isDark ? stitchPrimaryFixed : a.text,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text.rich(
                                TextSpan(
                                  children: _subtitleTimeSpans(
                                    context,
                                    s.updatedAt,
                                    theme,
                                    a,
                                  ),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    t(ctx, '${s.messages.length} 則',
                                        '${s.messages.length} msgs'),
                                    style: theme.textTheme.labelSmall
                                        ?.copyWith(color: a.textMuted),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded,
                                        size: 18, color: a.textMuted),
                                    tooltip:
                                        t(ctx, '刪除', 'Delete'),
                                    onPressed: () => _delete(s),
                                  ),
                                ],
                              ),
                              onTap: () => Navigator.pop(context, s),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// 副標題：相對時間（若有）+ 精確本地日期時間。
  List<InlineSpan> _subtitleTimeSpans(
    BuildContext context,
    DateTime updatedAt,
    ThemeData theme,
    AuraThemeColors a,
  ) {
    final rel = _relativeTimeLabel(context, updatedAt);
    final abs = _absoluteTimestamp(updatedAt);
    final baseStyle = theme.textTheme.bodySmall?.copyWith(color: a.textMuted);
    final absStyle = theme.textTheme.bodySmall?.copyWith(
      color: a.textSubtle,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    if (rel.isEmpty) {
      return [
        TextSpan(text: abs, style: absStyle),
      ];
    }
    return [
      TextSpan(text: rel, style: baseStyle),
      TextSpan(text: ' · ', style: baseStyle),
      TextSpan(text: abs, style: absStyle),
    ];
  }

  String _relativeTimeLabel(BuildContext context, DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return t(context, '剛剛', 'just now');
    if (diff.inHours < 1) {
      return t(context, '${diff.inMinutes} 分鐘前', '${diff.inMinutes}m ago');
    }
    if (diff.inDays < 1) {
      return t(context, '${diff.inHours} 小時前', '${diff.inHours}h ago');
    }
    if (diff.inDays < 7) {
      return t(context, '${diff.inDays} 天前', '${diff.inDays}d ago');
    }
    return '';
  }

  String _absoluteTimestamp(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year}/${_p(d.month)}/${_p(d.day)} '
        '${_p(d.hour)}:${_p(d.minute)}:${_p(d.second)}';
  }

  String _p(int n) => n.toString().padLeft(2, '0');
}
