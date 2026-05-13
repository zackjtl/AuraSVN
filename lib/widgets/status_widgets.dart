import 'package:aura_svn/app_theme.dart';
import 'package:aura_svn/language_scope.dart';
import 'package:flutter/material.dart';

BoxDecoration dashboardStatStripDecoration(
  BuildContext context, {
  required Color accentBorder,
}) {
  final a = aura(context);
  final edge = a.border;
  return BoxDecoration(
    color: a.surfaceAlt,
    border: Border(
      left: BorderSide(color: accentBorder, width: 3),
      top: BorderSide(color: edge, width: 1),
      right: BorderSide(color: edge, width: 1),
      bottom: BorderSide(color: edge, width: 1),
    ),
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accentBorder,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentBorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = aura(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: dashboardStatStripDecoration(
        context,
        accentBorder: accentBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: ' · ',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colors.textMuted),
                  ),
                  TextSpan(
                    text: label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class BackendStatusStyle {
  const BackendStatusStyle({
    required this.color,
    required this.icon,
  });

  final Color color;
  final IconData icon;
}

BackendStatusStyle backendStatusStyleForSummary(String summary) {
  switch (summary) {
    case '已連線':
      return const BackendStatusStyle(
        color: Colors.green,
        icon: Icons.check_circle_rounded,
      );
    case '檢查中':
      return const BackendStatusStyle(
        color: Colors.blue,
        icon: Icons.sync_rounded,
      );
    case '異常':
      return const BackendStatusStyle(
        color: Colors.red,
        icon: Icons.error_rounded,
      );
    case '未連線':
      return const BackendStatusStyle(
        color: Colors.orange,
        icon: Icons.link_off_rounded,
      );
    default:
      return const BackendStatusStyle(
        color: Colors.grey,
        icon: Icons.help_rounded,
      );
  }
}

String backendStatusSummary(String status) {
  if (status.contains('已連線')) {
    return '已連線';
  }
  if (status.contains('正在')) {
    return '檢查中';
  }
  if (status.contains('Connection refused') ||
      status.contains('拒絕') ||
      status.contains('errno = 1225') ||
      status.contains('無法連線')) {
    return '未連線';
  }
  if (status.contains('失敗') ||
      status.contains('無法') ||
      status.contains('中斷') ||
      status.contains('異常')) {
    return '異常';
  }
  return '未確認';
}

String localizedBackendSummary(BuildContext context, String summary) {
  switch (summary) {
    case '已連線':
      return t(context, '已連線', 'Connected');
    case '檢查中':
      return t(context, '檢查中', 'Checking');
    case '異常':
      return t(context, '異常', 'Error');
    case '未連線':
      return t(context, '未連線', 'Offline');
    default:
      return t(context, '未確認', 'Unknown');
  }
}

class BackendStatusCard extends StatelessWidget {
  const BackendStatusCard({
    super.key,
    required this.status,
    required this.onCheck,
    required this.onStart,
    required this.accentBorder,
  });

  final String status;
  final Future<void> Function() onCheck;
  final Future<void> Function() onStart;
  final Color accentBorder;

  @override
  Widget build(BuildContext context) {
    final summary = backendStatusSummary(status);
    final style = backendStatusStyleForSummary(summary);
    final theme = Theme.of(context);
    final colors = aura(context);
    final backendLabel = t(context, '後端', 'Backend');

    return PopupMenuButton<String>(
      tooltip: status,
      onSelected: (value) {
        if (value == 'check') {
          onCheck();
        } else if (value == 'start') {
          onStart();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'check',
          child: Text(t(context, '重新檢查連線', 'Recheck Connection')),
        ),
        PopupMenuItem(
          value: 'start',
          child: Text(t(context, '啟動本地後端', 'Start Local Backend')),
        ),
      ],
      child: Tooltip(
        message:
            '$status\n\n${t(context, '點擊可重新檢查或啟動本地後端。', 'Click to recheck or start the local backend.')}',
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: dashboardStatStripDecoration(
              context,
              accentBorder: accentBorder,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(style.icon, color: style.color, size: 19),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: localizedBackendSummary(context, summary),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: style.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: ' · ',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: colors.textMuted),
                        ),
                        TextSpan(
                          text: backendLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String localizedRuntimeText(BuildContext context, String text) {
  if (LanguageScope.of(context) != 'en') {
    return text;
  }
  const exact = {
    '尚未執行更新': 'Update not run yet',
    '尚未檢查後端狀態': 'Backend status not checked yet',
    '尚無本地資料': 'No local data yet',
    '已載入本地資料': 'Local data loaded',
    '設定已儲存': 'Settings saved',
    '正在讀取本地輸出資料': 'Reading local output data',
    '正在執行 SVN 增量更新': 'Running SVN incremental update',
    '更新完成，已重新載入資料': 'Update completed and data reloaded',
    '更新未完成': 'Update not completed',
  };
  return exact[text] ?? text;
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.text, required this.active});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final MaterialColor color = active ? Colors.blue : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            active
                ? Icons.hourglass_top_rounded
                : Icons.check_circle_outline_rounded,
            size: 18,
            color: color.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              localizedRuntimeText(context, text),
              style: TextStyle(
                color: color.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(child: SelectableText(error)),
        ],
      ),
    );
  }
}
