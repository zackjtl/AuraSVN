import 'package:aura_svn/app_theme.dart';
import 'package:aura_svn/branch_map_view.dart';
import 'package:aura_svn/language_scope.dart';
import 'package:aura_svn/models/app_data.dart';
import 'package:aura_svn/models/svn_repository.dart';
import 'package:aura_svn/notes_store.dart';
import 'package:aura_svn/widgets/commit_widgets.dart';
import 'package:aura_svn/widgets/misc_widgets.dart';
import 'package:aura_svn/widgets/status_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 頂部區與主內容之間：細青色邊線 + 向下漸層漏光（對齊 Stitch 類 HTML 效果）。
class DataPanelTopLeakDivider extends StatelessWidget {
  const DataPanelTopLeakDivider();

  /// 漸層向下延伸，拉長羽化；整體亮度靠低 alpha 壓低。
  static const double _glowExtent = 16;

  /// 下方 [TopologyCard]／[BranchMapView] 上移與此區重疊的像素，縮小羽化下方空白。
  static const double topologyPullUpOverlap = 50;

  @override
  Widget build(BuildContext context) {
    final line = Color.alphaBlend(
      cyberAccent.withOpacity(0.11),
      cyberBase,
    );
    return SizedBox(
      height: 1 + _glowExtent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 1, color: line),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.2, 0.42, 0.65, 0.86, 1.0],
                  colors: [
                    Color.alphaBlend(
                      cyberAccent.withOpacity(0.038),
                      cyberBase,
                    ),
                    Color.alphaBlend(
                      cyberAccent.withOpacity(0.022),
                      cyberBase,
                    ),
                    Color.alphaBlend(
                      cyberAccent.withOpacity(0.012),
                      cyberBase,
                    ),
                    Color.alphaBlend(
                      cyberAccent.withOpacity(0.006),
                      cyberBase,
                    ),
                    Color.alphaBlend(
                      cyberAccent.withOpacity(0.002),
                      cyberBase,
                    ),
                    cyberBase,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 白天：頂部細邊線 + 向下羽化至 [AuraThemeColors.surfaceAlt]；[TopologyCard] 為透明底讓漸層透出。
class DataPanelTopFeatherDividerLight extends StatelessWidget {
  const DataPanelTopFeatherDividerLight({super.key});

  static const double _glowExtent = 14;

  /// 與 [DataPanelTopLeakDivider.topologyPullUpOverlap] 相同用途（亮色主題）。
  static const double topologyPullUpOverlap = 42;

  @override
  Widget build(BuildContext context) {
    final a = aura(context);
    final base = a.surfaceAlt;
    final line = Color.alphaBlend(a.accent.withOpacity(0.22), a.border);
    return SizedBox(
      height: 1 + _glowExtent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 1, color: line),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.22, 0.5, 0.78, 1.0],
                  colors: [
                    Color.alphaBlend(a.accent.withOpacity(0.07), base),
                    Color.alphaBlend(a.accent.withOpacity(0.035), base),
                    Color.alphaBlend(a.border.withOpacity(0.28), base),
                    Color.alphaBlend(a.border.withOpacity(0.1), base),
                    base,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DataPanel extends StatelessWidget {
  const DataPanel({
    required this.repository,
    required this.data,
    required this.error,
    required this.isCompact,
    required this.showVisualMap,
    required this.settings,
    required this.backendStatus,
    required this.onCheckBackend,
    required this.onStartBackend,
    required this.onVisualMapChanged,
    required this.onAiChatPressed,
    this.onCheckoutPressed,
    this.onCheckoutBranch,
    this.onAiChatForBranch,
    required this.onBranchSelected,
    this.onBranchMapOrientationChanged,
  });

  final SvnRepository repository;
  final AppData data;
  final String? error;
  final bool isCompact;
  final bool showVisualMap;
  final AppSettings settings;
  final String backendStatus;
  final Future<void> Function() onCheckBackend;
  final Future<void> Function() onStartBackend;
  final ValueChanged<bool> onVisualMapChanged;
  final VoidCallback onAiChatPressed;
  final VoidCallback? onCheckoutPressed;
  /// 從分支／地圖節點開啟 Checkout 時帶入該分支路徑（組合 repo URL）；為 null 時不顯示按鈕。
  final ValueChanged<String>? onCheckoutBranch;
  /// 從分支卡片開啟 AI 時帶入該分支路徑；為 null 時不顯示卡片上的 AI 捷徑。
  final ValueChanged<String>? onAiChatForBranch;
  final ValueChanged<String> onBranchSelected;
  final ValueChanged<int>? onBranchMapOrientationChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = data.latestCommit;
    final isDark = theme.brightness == Brightness.dark;
    final auraTokens = aura(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        isDark
            ? DecoratedBox(
                decoration: const BoxDecoration(
                  color: cyberBase,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      repository.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.2,
                                        color: stitchPrimaryFixed,
                                      ),
                                    ),
                                    if (latest != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: auraTokens.accent
                                              .withOpacity(0.18),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'r${latest.revision}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: auraTokens.accent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  repository.url,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: auraTokens.textMuted,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (onCheckoutPressed != null)
                                OutlinedButton.icon(
                                  onPressed: onCheckoutPressed,
                                  icon: const Icon(Icons.download_for_offline_rounded),
                                  label: Text(t(context, 'Checkout', 'Checkout')),
                                ),
                              FilledButton.icon(
                                onPressed: onAiChatPressed,
                                icon: const Icon(Icons.auto_awesome_rounded),
                                label: Text(t(
                                  context,
                                  'AI助理',
                                  'AI Assistant',
                                )),
                              ),
                              SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    icon: Icon(Icons.account_tree_outlined),
                                    label: Text('Topology'),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    icon: Icon(Icons.hub_rounded),
                                    label: Text('Visual Map'),
                                  ),
                                ],
                                selected: {showVisualMap},
                                onSelectionChanged: (selection) {
                                  onVisualMapChanged(selection.first);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        ErrorBanner(error: error!),
                      ],
                      const SizedBox(height: 11),
                      LayoutBuilder(
                        builder: (context, c) {
                          const gap = 10.0;
                          final inner = c.maxWidth.isFinite && c.maxWidth > 0
                              ? c.maxWidth
                              : (MediaQuery.sizeOf(context).width - 96)
                                  .clamp(240.0, 2400.0);
                          final cardW = inner > 3 * gap
                              ? (inner - 3 * gap) / 4
                              : inner / 4;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: cardW,
                                child: MetricCard(
                                  label: t(context, 'Commits', 'Commits'),
                                  value: data.commits.length.toString(),
                                  icon: Icons.receipt_long_rounded,
                                  accentBorder: metricStripLeftCommits,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: cardW,
                                child: MetricCard(
                                  label: t(context, '節點', 'Nodes'),
                                  value: data.topology.length.toString(),
                                  icon: Icons.account_tree_outlined,
                                  accentBorder: metricStripLeftNodes,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: cardW,
                                child: BackendStatusCard(
                                  status: backendStatus,
                                  onCheck: onCheckBackend,
                                  onStart: onStartBackend,
                                  accentBorder: metricStripLeftBackend,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: cardW,
                                child: MetricCard(
                                  label: t(context, '作者', 'Author'),
                                  value: latest?.author.isNotEmpty == true
                                      ? latest!.author
                                      : '-',
                                  icon: Icons.person_search_rounded,
                                  accentBorder: metricStripLeftAuthor,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              )
              : Material(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        repository.name,
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (latest != null) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: aura(context)
                                                .accent
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'r${latest.revision}',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                              color: aura(context).accent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  Text(
                                    repository.url,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                      color: aura(context).textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (onCheckoutPressed != null)
                                  OutlinedButton.icon(
                                    onPressed: onCheckoutPressed,
                                    icon: const Icon(Icons.download_for_offline_rounded),
                                    label: Text(t(context, 'Checkout', 'Checkout')),
                                  ),
                                FilledButton.icon(
                                  onPressed: onAiChatPressed,
                                  icon: const Icon(Icons.auto_awesome_rounded),
                                  label: Text(t(
                                    context,
                                    'AI助理',
                                    'AI Assistant',
                                  )),
                                ),
                                SegmentedButton<bool>(
                                  style: ButtonStyle(
                                    backgroundColor:
                                        MaterialStateProperty.resolveWith(
                                            (states) {
                                      if (states.contains(
                                              MaterialState.selected) &&
                                          Theme.of(context).brightness ==
                                              Brightness.dark) {
                                        return const Color(0xFF17233F);
                                      }
                                      return null;
                                    }),
                                  ),
                                  segments: const [
                                    ButtonSegment(
                                      value: false,
                                      icon: Icon(Icons.account_tree_outlined),
                                      label: Text('Topology'),
                                    ),
                                    ButtonSegment(
                                      value: true,
                                      icon: Icon(Icons.hub_rounded),
                                      label: Text('Visual Map'),
                                    ),
                                  ],
                                  selected: {showVisualMap},
                                  onSelectionChanged: (selection) {
                                    onVisualMapChanged(selection.first);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 16),
                          ErrorBanner(error: error!),
                        ],
                        const SizedBox(height: 22),
                        LayoutBuilder(
                          builder: (context, c) {
                            const gap = 10.0;
                            final inner = c.maxWidth.isFinite && c.maxWidth > 0
                                ? c.maxWidth
                                : (MediaQuery.sizeOf(context).width - 96)
                                    .clamp(240.0, 2400.0);
                            final cardW = inner > 3 * gap
                                ? (inner - 3 * gap) / 4
                                : inner / 4;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: cardW,
                                  child: MetricCard(
                                    label: t(context, 'Commits', 'Commits'),
                                    value: data.commits.length.toString(),
                                    icon: Icons.receipt_long_rounded,
                                    accentBorder: metricStripLeftCommits,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: cardW,
                                  child: MetricCard(
                                    label: t(context, '節點', 'Nodes'),
                                    value: data.topology.length.toString(),
                                    icon: Icons.account_tree_outlined,
                                    accentBorder: metricStripLeftNodes,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: cardW,
                                  child: BackendStatusCard(
                                    status: backendStatus,
                                    onCheck: onCheckBackend,
                                    onStart: onStartBackend,
                                    accentBorder: metricStripLeftBackend,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: cardW,
                                  child: MetricCard(
                                    label: t(context, '作者', 'Author'),
                                    value: latest?.author.isNotEmpty == true
                                        ? latest!.author
                                        : '-',
                                    icon: Icons.person_search_rounded,
                                    accentBorder: metricStripLeftAuthor,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                ),
        if (isDark)
          const DataPanelTopLeakDivider()
        else
          const DataPanelTopFeatherDividerLight(),
        Expanded(
          child: data.isEmpty
              ? const EmptyDataCard()
              : showVisualMap
                  ? BranchMapView(
                      repository: repository,
                      data: data,
                      settings: settings,
                      onBranchSelected: onBranchSelected,
                      onAiChatForBranch: onAiChatForBranch,
                      onCheckoutBranch: onCheckoutBranch,
                      onBranchMapOrientationChanged:
                          onBranchMapOrientationChanged,
                    )
                  : TopologyCard(
                      data: data,
                      onBranchSelected: onBranchSelected,
                      onAiChatForBranch: onAiChatForBranch,
                      onCheckoutBranch: onCheckoutBranch,
                    ),
        ),
      ],
    );
  }
}