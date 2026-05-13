import 'package:aura_svn/app_theme.dart';
import 'package:aura_svn/language_scope.dart';
import 'package:aura_svn/models/svn_repository.dart';
import 'package:aura_svn/widgets/misc_widgets.dart';
import 'package:aura_svn/widgets/status_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({
    required this.selectedRepository,
    required this.repositories,
    required this.isRefreshing,
    required this.status,
    required this.rootPath,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onRepositorySelected,
    required this.onUpdatePressed,
    required this.onRepositoryProfilesPressed,
    required this.onSettingsPressed,
  });

  final SvnRepository selectedRepository;
  final List<SvnRepository> repositories;
  final bool isRefreshing;
  final String status;
  final String rootPath;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<SvnRepository> onRepositorySelected;
  final VoidCallback onUpdatePressed;
  final VoidCallback onRepositoryProfilesPressed;
  final VoidCallback onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auraTokens = aura(context);
    final isDark = theme.brightness == Brightness.dark;

    final sidebarDecoration = BoxDecoration(
      color: isDark ? auraTokens.surface : auraTokens.surfaceAlt,
      border: Border(
        right: BorderSide(
          color: auraTokens.border.withOpacity(isDark ? 0.22 : 0.4),
        ),
      ),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 28,
                offset: const Offset(4, 0),
              ),
            ]
          : null,
    );

    final sidebarActionGray = isDark
        ? const Color(0xFFC8D0D0)
        : auraTokens.textMuted;
    final sidebarActionStyle = TextButton.styleFrom(
      alignment: AlignmentDirectional.centerStart,
      foregroundColor: sidebarActionGray,
      backgroundColor: Colors.transparent,
      disabledForegroundColor: sidebarActionGray.withOpacity(0.45),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      minimumSize: const Size.fromHeight(44),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide.none,
      ),
    );

    if (collapsed) {
      return Container(
        decoration: sidebarDecoration,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            IconButton(
              tooltip: t(context, '展開側邊控制欄', 'Expand side panel'),
              onPressed: onToggleCollapsed,
              icon: const Icon(Icons.keyboard_double_arrow_right_rounded),
            ),
            const SizedBox(height: 4),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: auraTokens.border.withOpacity(0.4),
            ),
            const SizedBox(height: 14),
            Tooltip(
              message: selectedRepository.name,
              child: CircleAvatar(
                backgroundColor:
                    theme.colorScheme.primary.withOpacity(0.14),
                child: Text(
                  selectedRepository.name.replaceAll('_AP', '').substring(2),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            IconButton(
              tooltip: t(context, '執行增量更新', 'Run incremental update'),
              onPressed: isRefreshing ? null : onUpdatePressed,
              icon: isRefreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
            ),
            IconButton(
              tooltip: 'Repository Profiles',
              onPressed: isRefreshing ? null : onRepositoryProfilesPressed,
              icon: const Icon(Icons.storage_rounded),
            ),
            IconButton(
              tooltip: t(context, '設定', 'Settings'),
              onPressed: isRefreshing ? null : onSettingsPressed,
              icon: const Icon(Icons.settings_rounded),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: sidebarDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 84,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(child: AuraBrandMark()),
                  IconButton(
                    tooltip: t(context, '收合側邊控制欄', 'Collapse side panel'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    onPressed: onToggleCollapsed,
                    icon: const Icon(
                      Icons.keyboard_double_arrow_left_rounded,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 1,
            color: auraTokens.border.withOpacity(0.35),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text(
                    'REPOSITORIES',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                      color: auraTokens.textSubtle,
                      height: 1.2,
                    ),
                  ),
                ),
                RepositorySelector(
                  selectedRepository: selectedRepository,
                  repositories: repositories,
                  enabled: !isRefreshing,
                  onRepositorySelected: onRepositorySelected,
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InfoLine(label: 'URL', value: selectedRepository.url),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InfoLine(
                    label: t(context, '專案根目錄', 'Project Root'),
                    value: rootPath,
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    height: 1,
                    color: auraTokens.border.withOpacity(isDark ? 0.28 : 0.38),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed:
                        isRefreshing ? null : onRepositoryProfilesPressed,
                    icon: const Icon(Icons.storage_rounded),
                    label: const Text('Repository Profiles'),
                    style: sidebarActionStyle,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: isRefreshing ? null : onUpdatePressed,
                    icon: isRefreshing
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: sidebarActionGray,
                            ),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(
                      isRefreshing
                          ? t(context, '更新中...', 'Updating...')
                          : t(context, '執行增量更新', 'Run Incremental Update'),
                    ),
                    style: sidebarActionStyle,
                  ),
                ),
                const SizedBox(height: 10),
                StatusPill(text: status, active: isRefreshing),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: isRefreshing ? null : onSettingsPressed,
                    icon: const Icon(Icons.settings_rounded),
                    label: Text(t(context, '設定', 'Settings')),
                    style: sidebarActionStyle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RepositoryTile extends StatelessWidget {
  const RepositoryTile({
    super.key,
    required this.repository,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final SvnRepository repository;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tokens = aura(context);
    final borderColor = selected
        ? theme.colorScheme.primary.withOpacity(0.55)
        : tokens.border.withOpacity(isDark ? 0.22 : 0.35);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withOpacity(isDark ? 0.12 : 0.08)
                : (isDark ? cyberSurfaceSoft : tokens.surfaceSoft),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Icon(
                Icons.folder_special_outlined,
                size: 20,
                color: selected
                    ? theme.colorScheme.primary
                    : tokens.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      repository.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected ? theme.colorScheme.primary : tokens.text,
                      ),
                    ),
                    if (repository.subtitle.isNotEmpty)
                      Text(
                        repository.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (selected)
                Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class RepositorySelector extends StatefulWidget {
  const RepositorySelector({
    required this.selectedRepository,
    required this.repositories,
    required this.enabled,
    required this.onRepositorySelected,
  });

  final SvnRepository selectedRepository;
  final List<SvnRepository> repositories;
  final bool enabled;
  final ValueChanged<SvnRepository> onRepositorySelected;

  @override
  State<RepositorySelector> createState() => RepositorySelectorState();
}

class RepositorySelectorState extends State<RepositorySelector> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final repository in widget.repositories)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: RepositoryTile(
              repository: repository,
              selected: repository == widget.selectedRepository,
              enabled: widget.enabled,
              onTap: () {
                if (repository == widget.selectedRepository) {
                  return;
                }
                widget.onRepositorySelected(repository);
              },
            ),
          ),
      ],
    );
  }
}

class AuraBrandMark extends StatelessWidget {
  const AuraBrandMark();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auraTokens = aura(context);
    return Align(
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Aura ',
                      style: GoogleFonts.inter(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? stitchPrimaryFixed
                            : auraTokens.accent,
                        fontSize: 22 * 1.3,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        height: 1,
                      ),
                    ),
                    TextSpan(
                      text: 'SVN',
                      style: GoogleFonts.inter(
                        color: auraTokens.text,
                        fontSize: 22 * 1.3,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 3),
              Text(
                'Insightful SVN Client',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  textStyle: theme.textTheme.bodySmall,
                  color: auraTokens.textMuted,
                  height: 1,
                  fontSize: 12,
                  letterSpacing: 0.16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OutputConsole extends StatelessWidget {
  const OutputConsole({
    required this.logs,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final List<String> logs;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    const collapsedHeight = 64.0;
    const headerHeight = 54.0;
    final theme = Theme.of(context);
    final a = aura(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? cyberMainPanel : a.surfaceAlt;
    final topBorder = isDark ? const Color(0xFF334155) : a.border;
    final innerDivider = isDark ? const Color(0xFF1E293B) : a.border.withOpacity(0.65);
    final titleColor = isDark ? const Color(0xFFE2E8F0) : a.text;
    final iconTint = isDark ? const Color(0xFF93C5FD) : a.accent;
    final previewMuted = isDark ? const Color(0xFF94A3B8) : a.textMuted;
    final logLineColor = isDark ? const Color(0xFFE2E8F0) : a.text;
    final emptyHintColor = isDark ? const Color(0xFF94A3B8) : a.textMuted;
    final iconButtonFg = isDark ? const Color(0xFFE2E8F0) : a.textMuted;

    final latestLine = logs.isEmpty
        ? t(
            context,
            '尚無執行紀錄。按下「執行增量更新」後，SVN loader 輸出會顯示在這裡。',
            'No run logs yet. After running an incremental update, SVN loader output will appear here.',
          )
        : logs.last;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: expanded ? 260 : collapsedHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(color: topBorder),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
              height: headerHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.terminal_rounded,
                      color: iconTint,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Output Console',
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        latestLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: previewMuted,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: t(context, '複製全部', 'Copy All'),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                      onPressed: logs.isEmpty
                          ? null
                          : () {
                              Clipboard.setData(
                                ClipboardData(text: logs.join('\n')),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(t(
                                    context,
                                    '已複製全部執行紀錄',
                                    'Copied all run logs',
                                  )),
                                ),
                              );
                            },
                      icon: const Icon(Icons.copy_rounded),
                      color: iconButtonFg,
                    ),
                    IconButton(
                      tooltip: expanded
                          ? t(context, '收合 Console', 'Collapse Console')
                          : t(context, '展開 Console', 'Expand Console'),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                      onPressed: onToggleExpanded,
                      icon: Icon(
                        expanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                      ),
                      color: iconButtonFg,
                    ),
                  ],
                ),
              ),
            ),
            if (expanded)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: innerDivider),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: logs.isEmpty
                      ? Text(
                          latestLine,
                          style: TextStyle(
                            color: emptyHintColor,
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        )
                      : SelectionArea(
                          child: ListView.builder(
                            itemCount: logs.length,
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                logs[index],
                                style: TextStyle(
                                  color: logLineColor,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
          ],
        ),
    );
  }
}