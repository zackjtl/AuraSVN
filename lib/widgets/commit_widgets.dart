import 'dart:ui' show ImageFilter;

import 'package:aura_svn/app_theme.dart';
import 'package:aura_svn/diff/diff_widgets.dart';
import 'package:aura_svn/language_scope.dart';
import 'package:aura_svn/models/app_data.dart';
import 'package:aura_svn/models/branch_node.dart';
import 'package:aura_svn/models/commit_record.dart';
import 'package:aura_svn/models/svn_repository.dart';
import 'package:aura_svn/notes_store.dart';
import 'package:aura_svn/utils/branch_paths.dart';
import 'package:aura_svn/utils/helpers.dart';
import 'package:aura_svn/widgets/misc_widgets.dart';
import 'package:aura_svn/widgets/status_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// 分支／Commit 列表標題旁小圖示槽寬（固定，避免 hover 時版面跳動）。
const double _kListActionSlotSize = 26;
const double _kListActionIconSize = 15;

/// Branch／Commit 列表卡片外框圓角（Topology 與 Commit 列一致）。
const double _kBranchCommitListCardRadius = 5.0;
/// Commit 卡片相對於時間軸可用寬度的比例（其餘左右均分為外側留白）。
const double _kCommitCardWidthFactor = 0.9;
/// 時間軸列內：卡片區左（軌道+縫）+ 右 padding，與 [CommitTimelineItem] 內 [Padding] 一致。
const double _kCommitTimelineLaneHorizontal = 36;
/// Commit 列表 ListView 與標題對齊用之水平 padding（須與 `main.dart` 分支詳情頁一致）。
const double kBranchCommitListPadLeftDay = 8;
const double kBranchCommitListPadLeftNight = 12;
const double kBranchCommitListPadRight = 12;
/// 白天 Commit 時間軸垂直線與節點顏色。
const Color kCommitTimelineDayColor = Color(0xFF90AADD);
/// 白天 Commit 卡片展開時左側強調邊條。
const Color kCommitExpandedEdgeLight = Color(0xFF60A5FA);
/// 夜晚 Commit 卡片展開時左側強調邊條。
const Color kCommitExpandedEdgeDark = Color(0xFF6898CB);
/// 路徑列「檔名 + 獨立視窗」區塊內為圖示保留的寬度（含間距）。
const double _kPathTitleOpenWindowReserve = 34.0;

/// Commit 內嵌 diff 載入中時，先展開的固定高度（載入完成後改由內容決定高度）。
const double _kEmbeddedDiffLoadingBodyHeight = 220;

/// ListView 單列可用寬 [listContentWidth] 時，時間軸＋卡片塊總寬。
double commitTimelineBlockWidthForListContent(double listContentWidth) {
  final inner = (listContentWidth - _kCommitTimelineLaneHorizontal)
      .clamp(0.0, double.infinity);
  return _kCommitTimelineLaneHorizontal + inner * _kCommitCardWidthFactor;
}

/// 置中時塊左側留白（list 內容左緣至時間軸左緣）。
double commitTimelineCenteringLeading(double listContentWidth) {
  final b = commitTimelineBlockWidthForListContent(listContentWidth);
  return ((listContentWidth - b) / 2).clamp(0.0, double.infinity);
}

/// 分支詳情區寬 [sectionInnerWidth] 下，「Commit 歷史」標題列左 padding（與時間軸左緣對齊）。
double commitHistoryTitlePaddingLeft(
  double sectionInnerWidth, {
  required bool isDark,
}) {
  final listPadL =
      isDark ? kBranchCommitListPadLeftNight : kBranchCommitListPadLeftDay;
  final listPadR = kBranchCommitListPadRight;
  final contentW =
      (sectionInnerWidth - listPadL - listPadR).clamp(0.0, double.infinity);
  return listPadL + commitTimelineCenteringLeading(contentW);
}

/// 白天 Branch list 與 Commit list 卡片共用之 mouse-over 底色。
Color _dayBranchCommitCardHoverFill(AuraThemeColors a) {
  final base = a.surface;
  return Color.lerp(base, a.surfaceSoft, 0.52) ?? base;
}

/// 無框線；hover 時亮色主題為淺灰疊加，暗色為略亮於 [blendBase]。
ButtonStyle _listActionIconStyle({
  required bool isDark,
  required Color blendBase,
  required Color iconColor,
}) {
  return ButtonStyle(
    minimumSize:
        const MaterialStatePropertyAll(Size(_kListActionSlotSize, _kListActionSlotSize)),
    maximumSize:
        const MaterialStatePropertyAll(Size(_kListActionSlotSize, _kListActionSlotSize)),
    padding: MaterialStateProperty.all(EdgeInsets.zero),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    elevation: const MaterialStatePropertyAll(0),
    shadowColor: const MaterialStatePropertyAll(Colors.transparent),
    shape: MaterialStateProperty.all(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    side: const MaterialStatePropertyAll(BorderSide.none),
    overlayColor: MaterialStateProperty.all(Colors.transparent),
    backgroundColor: MaterialStateProperty.resolveWith((states) {
      if (states.contains(MaterialState.hovered)) {
        return isDark
            ? Color.alphaBlend(Colors.white.withOpacity(0.12), blendBase)
            : Color.alphaBlend(Colors.black.withOpacity(0.08), blendBase);
      }
      return Colors.transparent;
    }),
    foregroundColor: MaterialStateProperty.all(iconColor),
    iconColor: MaterialStateProperty.all(iconColor),
  );
}

class TopologyCard extends StatelessWidget {
  const TopologyCard({
    required this.data,
    required this.onBranchSelected,
    this.onAiChatForBranch,
    this.onCheckoutBranch,
  });

  final AppData data;
  final ValueChanged<String> onBranchSelected;
  final ValueChanged<String>? onAiChatForBranch;
  final ValueChanged<String>? onCheckoutBranch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nodes = data.topology.entries.toList()
      ..sort((a, b) {
        final aTrunk = isTrunkPath(a.key);
        final bTrunk = isTrunkPath(b.key);
        if (aTrunk != bTrunk) {
          return aTrunk ? -1 : 1;
        }
        return a.key.compareTo(b.key);
      });

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Topology',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                child: ListView.separated(
                  padding: const EdgeInsets.only(right: 14),
                  itemCount: nodes.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = nodes[index];
                    return TopologyNodeTile(
                      path: entry.key,
                      node: entry.value,
                      selected: false,
                      onTap: () => onBranchSelected(entry.key),
                      onCheckoutPressed: onCheckoutBranch == null
                          ? null
                          : () => onCheckoutBranch!(entry.key),
                      onAiChatPressed: onAiChatForBranch == null
                          ? null
                          : () => onAiChatForBranch!(entry.key),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
    );
  }
}

class TopologyNodeTile extends StatefulWidget {
  const TopologyNodeTile({
    required this.path,
    required this.node,
    required this.selected,
    required this.onTap,
    this.onCheckoutPressed,
    this.onAiChatPressed,
  });

  final String path;
  final BranchNode node;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onCheckoutPressed;
  final VoidCallback? onAiChatPressed;

  @override
  State<TopologyNodeTile> createState() => _TopologyNodeTileState();
}

class _TopologyNodeTileState extends State<TopologyNodeTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = widget.node.children;
    final path = widget.path;

    // 根據路徑決定左側邊框顏色（Ayu Mirage 色系）
    final Color baseAccentColor;
    if (path.startsWith('/branches')) {
      baseAccentColor = const Color(0xFFA074C4); // 紫
    } else if (path.startsWith('/trunk')) {
      baseAccentColor = const Color(0xFF73D0FF); // 淺藍
    } else if (path.startsWith('/tags')) {
      baseAccentColor = const Color(0xFF69B458); // 綠
    } else {
      baseAccentColor = const Color(0xFF707A8C); // 灰藍
    }

    // 選中狀態覆蓋色條，icon 保持原始路徑色
    final Color accentBorderColor = widget.selected
        ? theme.colorScheme.primary.withOpacity(0.35)
        : baseAccentColor;

    final isDark = theme.brightness == Brightness.dark;
    final a = aura(context);
    final cardFill = isDark ? cyberSurfaceSoft : a.surface;
    // 白天：surface 與 surfaceAlt 過近；hover 改向 surfaceSoft 插值，對比更清楚。
    final hoverFill = isDark
        ? Color.alphaBlend(Colors.white.withOpacity(0.05), cyberSurfaceSoft)
        : _dayBranchCommitCardHoverFill(a);
    final hasBranchActions = widget.onCheckoutPressed != null ||
        widget.onAiChatPressed != null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_kBranchCommitListCardRadius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(14),
            decoration: dashboardStatStripDecoration(
              context,
              accentBorder: accentBorderColor,
            ).copyWith(
              color: _hovering ? hoverFill : cardFill,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (widget.node.kind == 'tag')
                      Icon(
                        Icons.sell_outlined,
                        color: theme.colorScheme.primary,
                      )
                    else if (isTrunkPath(path))
                      Icon(
                        Icons.account_tree_outlined,
                        color: theme.colorScheme.primary,
                      )
                    else
                      Icon(
                        Icons.call_split_rounded,
                        color: baseAccentColor,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        path,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (hasBranchActions)
                      SizedBox(
                        width: _kListActionSlotSize * 2,
                        height: _kListActionSlotSize,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: _kListActionSlotSize,
                              height: _kListActionSlotSize,
                              child: widget.onCheckoutPressed != null
                                  ? Tooltip(
                                      message: t(
                                        context,
                                        'Checkout 此分支',
                                        'Checkout this branch',
                                      ),
                                      child: IconButton(
                                        style: _listActionIconStyle(
                                          isDark: isDark,
                                          blendBase:
                                              _hovering ? hoverFill : cardFill,
                                          iconColor: a.accent,
                                        ),
                                        onPressed: widget.onCheckoutPressed,
                                        icon: Icon(
                                          Icons.download_for_offline_outlined,
                                          size: _kListActionIconSize,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            SizedBox(
                              width: _kListActionSlotSize,
                              height: _kListActionSlotSize,
                              child: widget.onAiChatPressed != null
                                  ? Tooltip(
                                      message: t(
                                        context,
                                        '以此分支開啟 AI助理',
                                        'Open AI Assistant for this branch',
                                      ),
                                      child: IconButton(
                                        style: _listActionIconStyle(
                                          isDark: isDark,
                                          blendBase:
                                              _hovering ? hoverFill : cardFill,
                                          iconColor: a.accent,
                                        ),
                                        onPressed: widget.onAiChatPressed,
                                        icon: Icon(
                                          Icons.auto_awesome_outlined,
                                          size: _kListActionIconSize,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SmallChip(label: 'kind', value: widget.node.kind ?? 'root'),
                    SmallChip(
                        label: 'origin_rev',
                        value: widget.node.originRev?.toString() ?? '-'),
                    SmallChip(
                        label: 'parent_rev',
                        value: widget.node.parentRev?.toString() ?? '-'),
                    SmallChip(
                        label: 'children', value: children.length.toString()),
                  ],
                ),
                if (widget.node.parent != null) ...[
                  const SizedBox(height: 10),
                  InfoLine(label: 'parent', value: widget.node.parent!),
                ],
                if (children.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'children',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: aura(context).textMuted),
                  ),
                  const SizedBox(height: 4),
                  ...children.map(
                    (child) => Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.subdirectory_arrow_right_rounded,
                              size: 16),
                          const SizedBox(width: 6),
                          Expanded(child: Text(child)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 朝上實心箭頭：窄三角箭頭 + 底邊下的箭尾；尺寸對齊鄰近 branch 的 Material Icon。

class CommitTimelineItem extends StatefulWidget {
  const CommitTimelineItem({
    super.key,
    required this.commit,
    required this.expanded,
    required this.onExpandToggle,
    this.repository,
    this.settings,
    this.isLatest = false,
    this.onAiAnalyzeCommit,
    this.onCheckoutPressed,
  });

  final CommitRecord commit;
  final bool expanded;
  final VoidCallback onExpandToggle;
  final SvnRepository? repository;
  final AppSettings? settings;
  final bool isLatest;
  final VoidCallback? onAiAnalyzeCommit;
  final VoidCallback? onCheckoutPressed;

  @override
  State<CommitTimelineItem> createState() => _CommitTimelineItemState();
}

class _CommitTimelineItemState extends State<CommitTimelineItem> {
  bool _hoverRow = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 夜間維持 cyan 軌道；白天線與節點皆為 #6688CC。
    final railLineColor =
        isDark ? stitchPrimaryFixed : kCommitTimelineDayColor;
    final railNodeColor =
        isDark ? stitchPrimaryFixed : kCommitTimelineDayColor;
    final railLineOpacity = isDark ? 0.32 : 1.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoverRow = true),
      onExit: (_) => setState(() => _hoverRow = false),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final listW = constraints.maxWidth;
          final inner = (listW - _kCommitTimelineLaneHorizontal)
              .clamp(0.0, double.infinity);
          final tileW = inner * _kCommitCardWidthFactor;
          final blockW = commitTimelineBlockWidthForListContent(listW);
          final lead = commitTimelineCenteringLeading(listW);

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: lead),
            child: SizedBox(
              width: blockW,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 22,
                    child: CustomPaint(
                      painter: TimelineRailPainter(
                        lineColor: railLineColor,
                        nodeColor: railNodeColor,
                        lineOpacity: railLineOpacity,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 24,
                      right: 12,
                      bottom: 16,
                    ),
                    child: SizedBox(
                      width: tileW,
                      child: CommitTile(
                        commit: widget.commit,
                        repository: widget.repository,
                        settings: widget.settings,
                        expanded: widget.expanded,
                        isLatest: widget.isLatest,
                        onExpandToggle: widget.onExpandToggle,
                        onCheckoutPressed: widget.onCheckoutPressed,
                        onAiAnalyzeCommit: widget.onAiAnalyzeCommit,
                        showHoverActions: _hoverRow,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class TimelineRailPainter extends CustomPainter {
  TimelineRailPainter({
    required this.lineColor,
    required this.nodeColor,
    this.lineOpacity = 0.32,
  });

  final Color lineColor;
  final Color nodeColor;
  /// 垂直線透明度（與 [lineColor] 相乘）；白天版可略高以便在淺底辨識。
  final double lineOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width * 0.45;
    const nodeY = 22.0;

    final linePaint = Paint()
      ..color = lineColor.withOpacity(lineOpacity.clamp(0.0, 1.0))
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.butt;

    // 整段垂直線貫穿本列（含與下一筆之間的間距），與上下列銜接成連續軌道
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      linePaint,
    );

    final nodePaint = Paint()..color = nodeColor;
    canvas.drawCircle(Offset(centerX, nodeY), 4, nodePaint);
  }

  @override
  bool shouldRepaint(covariant TimelineRailPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.nodeColor != nodeColor ||
        oldDelegate.lineOpacity != lineOpacity;
  }
}

class CommitTile extends StatefulWidget {
  const CommitTile({
    required this.commit,
    required this.expanded,
    required this.onExpandToggle,
    this.repository,
    this.settings,
    this.isLatest = false,
    this.onCheckoutPressed,
    this.onAiAnalyzeCommit,
    this.showHoverActions = false,
  });

  final CommitRecord commit;
  final bool expanded;
  final VoidCallback onExpandToggle;
  final SvnRepository? repository;
  final AppSettings? settings;
  final bool isLatest;
  final VoidCallback? onCheckoutPressed;
  final VoidCallback? onAiAnalyzeCommit;
  final bool showHoverActions;

  @override
  State<CommitTile> createState() => CommitTileState();
}

class CommitTileState extends State<CommitTile> {
  final Set<String> _expandedDiffPaths = {};
  final Set<String> _diffLoadingPaths = {};
  final Map<String, RevisionDiffResult> _diffResults = {};
  final Map<String, String> _diffErrors = {};

  void _togglePathDiff(ChangedPath path) {
    final key = path.path;
    var shouldFetch = false;
    setState(() {
      if (_expandedDiffPaths.contains(key)) {
        _expandedDiffPaths.remove(key);
      } else {
        _expandedDiffPaths.add(key);
        // Copy operations (branch creation) can involve thousands of files;
        // skip diff fetch to avoid hanging the UI.
        shouldFetch = path.copyFromPath == null &&
            !_diffResults.containsKey(key) &&
            !_diffLoadingPaths.contains(key);
      }
    });
    if (shouldFetch) {
      _fetchDiffForPath(path);
    }
  }

  Future<void> _fetchDiffForPath(ChangedPath path, {bool refresh = false}) async {
    final key = path.path;
    final repository = widget.repository;
    final settings = widget.settings;
    if (repository == null || settings == null) {
      return;
    }

    setState(() {
      _diffLoadingPaths.add(key);
      _diffErrors.remove(key);
      if (refresh) {
        _diffResults.remove(key);
      }
    });

    try {
      final result = await loadRevisionDiff(
        settings: settings,
        repository: repository,
        revision: widget.commit.revision,
        path: path.path,
        refresh: refresh,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _diffResults[key] = result;
        _diffLoadingPaths.remove(key);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _diffErrors[key] = error.toString();
        _diffLoadingPaths.remove(key);
      });
    }
  }

  Future<void> _ensureDiffReady(ChangedPath path) async {
    final key = path.path;
    final repository = widget.repository;
    final settings = widget.settings;
    if (repository == null || settings == null) {
      return;
    }
    if (_diffResults.containsKey(key) || _diffErrors.containsKey(key)) {
      return;
    }
    if (_diffLoadingPaths.contains(key)) {
      while (mounted && _diffLoadingPaths.contains(key)) {
        await Future<void>.delayed(const Duration(milliseconds: 32));
      }
      return;
    }
    await _fetchDiffForPath(path);
  }

  Future<void> _openStandaloneDiffWindow(ChangedPath path) async {
    await _ensureDiffReady(path);
    if (!mounted) {
      return;
    }
    final key = path.path;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel:
          MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final cached = _diffResults[key];
            final loading = _diffLoadingPaths.contains(key);
            final error = _diffErrors[key];
            final screen = MediaQuery.sizeOf(dialogContext);
            final theme = Theme.of(dialogContext);
            final isDark = theme.brightness == Brightness.dark;
            final auraTokens = aura(dialogContext);
            final diffWindowBg =
                isDark ? cyberMainPanel : auraTokens.surface;
            final barrierTint = isDark
                ? Colors.black.withOpacity(0.42)
                : Colors.black.withOpacity(0.22);

            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(dialogContext).pop(),
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          color: barrierTint,
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: RepaintBoundary(
                    child: SizedBox(
                      width: screen.width * 0.85,
                      height: screen.height * 0.85,
                      child: ColoredBox(
                        color: diffWindowBg,
                        child: InlineUnifiedDiffPanel(
                          fillAvailableHeight: true,
                          diffText: cached?.diff ?? '',
                          isLoading: loading,
                          errorText: error,
                          headerPath: path.path,
                          onCopy: cached == null
                              ? null
                              : () {
                                  Clipboard.setData(
                                    ClipboardData(text: cached.diff),
                                  );
                                  ScaffoldMessenger.maybeOf(context)
                                      ?.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        t(
                                          context,
                                          '已複製 Diff',
                                          'Diff copied',
                                        ),
                                      ),
                                    ),
                                  );
                                },
                          onRefresh: widget.repository == null ||
                                  widget.settings == null
                              ? null
                              : () async {
                                  await _fetchDiffForPath(path, refresh: true);
                                  if (dialogContext.mounted) {
                                    setModalState(() {});
                                  }
                                },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auraTokens = aura(context);
    final commit = widget.commit;
    final isDark = theme.brightness == Brightness.dark;
    final hl = widget.expanded;
    final ticketIds = commit.ticketId
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final hasCommitActions = widget.onCheckoutPressed != null ||
        widget.onAiAnalyzeCommit != null;
    final showCommitActions = widget.showHoverActions || widget.expanded;
    final cardFillLight = auraTokens.surface;
    final hoverFillLight = _dayBranchCommitCardHoverFill(auraTokens);
    final Color commitTileBackground;
    if (isDark) {
      commitTileBackground = stitchGlassFill;
    } else {
      commitTileBackground =
          widget.showHoverActions ? hoverFillLight : cardFillLight;
    }
    final actionBlendBase =
        isDark ? stitchGlassFill : commitTileBackground;

    return Theme(
      data: theme.copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kBranchCommitListCardRadius),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: commitTileBackground,
                // 不可與非均勻邊框色並用 borderRadius（Flutter assert）；圓角由外層 ClipRRect 裁切。
                border: Border(
                  left: BorderSide(
                    width: hl ? 2 : 1,
                    color: hl
                        ? (isDark ? kCommitExpandedEdgeDark : kCommitExpandedEdgeLight)
                        : (isDark
                            ? stitchGlassBorder
                            : auraTokens.border.withOpacity(0.65)),
                  ),
                  top: BorderSide(
                    color: isDark
                        ? stitchGlassBorder
                        : auraTokens.border.withOpacity(0.4),
                  ),
                  right: BorderSide(
                    color: isDark
                        ? stitchGlassBorder
                        : auraTokens.border.withOpacity(0.4),
                  ),
                  bottom: BorderSide(
                    color: isDark
                        ? stitchGlassBorder
                        : auraTokens.border.withOpacity(0.4),
                  ),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: Colors.transparent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InkWell(
                      overlayColor: MaterialStateProperty.all(Colors.transparent),
                      onTap: () => widget.onExpandToggle(),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'r${commit.revision}',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                          fontSize: widget.isLatest ? 14 : 13,
                                          fontWeight: FontWeight.w700,
                                          color: widget.isLatest
                                              ? auraTokens.accent
                                              : (hl
                                                  ? (isDark
                                                      ? stitchPrimaryFixed
                                                      : auraTokens.text)
                                                  : auraTokens.textMuted),
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      if (widget.isLatest) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: auraTokens.accent
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Latest',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: auraTokens.accent,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      if (hasCommitActions)
                                        SizedBox(
                                          width: _kListActionSlotSize * 2,
                                          height: _kListActionSlotSize,
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Opacity(
                                              opacity:
                                                  showCommitActions ? 1 : 0,
                                              child: IgnorePointer(
                                                ignoring: !showCommitActions,
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    SizedBox(
                                                      width:
                                                          _kListActionSlotSize,
                                                      height:
                                                          _kListActionSlotSize,
                                                      child: widget
                                                                  .onCheckoutPressed !=
                                                              null
                                                          ? Tooltip(
                                                              message: t(
                                                                context,
                                                                'Checkout 此修訂',
                                                                'Checkout this revision',
                                                              ),
                                                              child: IconButton(
                                                                style:
                                                                    _listActionIconStyle(
                                                                  isDark:
                                                                      isDark,
                                                                  blendBase:
                                                                      actionBlendBase,
                                                                  iconColor:
                                                                      auraTokens
                                                                          .accent,
                                                                ),
                                                                onPressed: widget
                                                                    .onCheckoutPressed,
                                                                icon: Icon(
                                                                  Icons
                                                                      .download_for_offline_outlined,
                                                                  size:
                                                                      _kListActionIconSize,
                                                                ),
                                                              ),
                                                            )
                                                          : const SizedBox
                                                              .shrink(),
                                                    ),
                                                    SizedBox(
                                                      width:
                                                          _kListActionSlotSize,
                                                      height:
                                                          _kListActionSlotSize,
                                                      child: widget
                                                                  .onAiAnalyzeCommit !=
                                                              null
                                                          ? Tooltip(
                                                              message: t(
                                                                context,
                                                                '以此修訂開啟 AI助理',
                                                                'Open AI Assistant for this revision',
                                                              ),
                                                              child: IconButton(
                                                                style:
                                                                    _listActionIconStyle(
                                                                  isDark:
                                                                      isDark,
                                                                  blendBase:
                                                                      actionBlendBase,
                                                                  iconColor:
                                                                      auraTokens
                                                                          .accent,
                                                                ),
                                                                onPressed: widget
                                                                    .onAiAnalyzeCommit,
                                                                icon: Icon(
                                                                  Icons
                                                                      .auto_awesome_outlined,
                                                                  size:
                                                                      _kListActionIconSize,
                                                                ),
                                                              ),
                                                            )
                                                          : const SizedBox
                                                              .shrink(),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (hasCommitActions)
                                        const SizedBox(width: 6),
                                      Text(
                                        shortCommitDate(commit.date),
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11,
                                          letterSpacing: 0.55,
                                          color: auraTokens.textSubtle,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    commit.message.isEmpty
                                        ? '(no message)'
                                        : commit.message,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: auraTokens.text,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Container(
                                        width: 18,
                                        height: 18,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: auraTokens.surfaceSoft,
                                          border: Border.all(
                                            color: auraTokens.border
                                                .withOpacity(0.6),
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          commit.author.isEmpty
                                              ? '?'
                                              : commit.author
                                                  .substring(0, 1)
                                                  .toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: auraTokens.textMuted,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          commit.author.isEmpty
                                              ? 'unknown'
                                              : commit.author,
                                          style: TextStyle(
                                            fontSize: 11,
                                            letterSpacing: 0.4,
                                            color: auraTokens.textSubtle,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (ticketIds.isNotEmpty)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            for (var i = 0;
                                                i < ticketIds.length;
                                                i++) ...[
                                              if (i > 0)
                                                const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: auraTokens.violet
                                                      .withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  ticketIds[i],
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: auraTokens.violet,
                                                    letterSpacing: 0.4,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: auraTokens.surfaceSoft,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                            color: auraTokens.border
                                                .withOpacity(0.5),
                                          ),
                                        ),
                                        child: Text(
                                          '${commit.changedPaths.length} paths',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: auraTokens.textMuted,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              widget.expanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: auraTokens.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.expanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InfoLine(label: 'date', value: commit.date),
                            const SizedBox(height: 10),
                            Text(
                              t(
                                context,
                                '點路徑標題列展開 Diff（展開後即載入）；複製與重新抓取在列右側。',
                                'Tap a path title bar to expand and load the diff. Copy and refresh are on the right.',
                              ),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: auraTokens.textMuted),
                            ),
                            const SizedBox(height: 10),
                            ...commit.changedPaths.take(30).map(
                              (path) {
                                final key = path.path;
                                final expandedPath =
                                    _expandedDiffPaths.contains(key);
                                final loadingPath =
                                    _diffLoadingPaths.contains(key);
                                final cached = _diffResults[key];
                                final error = _diffErrors[key];
                                final pathLabel = path.copyFromPath == null
                                    ? path.path
                                    : '${path.path}  <-  ${path.copyFromPath}@${path.copyFromRev ?? '-'}';
                                final isCopy = path.copyFromPath != null;
                                final canUseDiff = !isCopy &&
                                    widget.repository != null &&
                                    widget.settings != null;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(
                                        _kBranchCommitListCardRadius,
                                      ),
                                      border: Border.all(
                                        color: isDark
                                            ? stitchGlassBorder.withOpacity(0.55)
                                            : auraTokens.border.withOpacity(0.55),
                                      ),
                                      color: isDark
                                          ? stitchGlassFill.withOpacity(0.42)
                                          : auraTokens.surface,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: (canUseDiff || isCopy)
                                                ? () => _togglePathDiff(path)
                                                : null,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 8,
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    width: 28,
                                                    alignment: Alignment.center,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: actionColor(
                                                        path.action,
                                                      ).withOpacity(0.12),
                                                      borderRadius:
                                                          BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      path.action,
                                                      style: TextStyle(
                                                        color: actionColor(
                                                          path.action,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: LayoutBuilder(
                                                      builder:
                                                          (context, constraints) {
                                                        final textMaxWidth =
                                                            (constraints.maxWidth -
                                                                    _kPathTitleOpenWindowReserve)
                                                                .clamp(
                                                                  0.0,
                                                                  double.infinity,
                                                                );
                                                        return Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .center,
                                                          children: [
                                                            ConstrainedBox(
                                                              constraints:
                                                                  BoxConstraints(
                                                                maxWidth:
                                                                    textMaxWidth,
                                                              ),
                                                              child: Text(
                                                                pathLabel,
                                                                maxLines: 2,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style:
                                                                    TextStyle(
                                                                  color: aura(context).text,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 12,
                                                                ),
                                                              ),
                                                            ),
                                                            if (!isCopy)
                                                            IconButton(
                                                              tooltip: t(
                                                                context,
                                                                '獨立視窗',
                                                                'Separate window',
                                                              ),
                                                              visualDensity:
                                                                  VisualDensity
                                                                      .compact,
                                                              padding:
                                                                  EdgeInsets.zero,
                                                              constraints:
                                                                  const BoxConstraints(
                                                                minWidth: 28,
                                                                minHeight: 28,
                                                              ),
                                                              icon: Icon(
                                                                Icons
                                                                    .open_in_new_rounded,
                                                                size: 14,
                                                                color: canUseDiff
                                                                    ? auraTokens
                                                                        .textMuted
                                                                        .withOpacity(
                                                                          0.55,
                                                                        )
                                                                    : auraTokens
                                                                        .textMuted
                                                                        .withOpacity(
                                                                          0.28,
                                                                        ),
                                                              ),
                                                              onPressed:
                                                                  canUseDiff
                                                                      ? () =>
                                                                          _openStandaloneDiffWindow(
                                                                            path,
                                                                          )
                                                                      : null,
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  if (!isCopy &&
                                                      expandedPath &&
                                                      cached != null &&
                                                      canUseDiff)
                                                    IconButton(
                                                      tooltip: t(
                                                        context,
                                                        '複製 Diff',
                                                        'Copy Diff',
                                                      ),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(
                                                        minWidth: 32,
                                                        minHeight: 32,
                                                      ),
                                                      icon: Icon(
                                                        Icons.copy_rounded,
                                                        size: 18,
                                                        color: auraTokens.textMuted,
                                                      ),
                                                      onPressed: () {
                                                        Clipboard.setData(
                                                          ClipboardData(
                                                            text: cached.diff,
                                                          ),
                                                        );
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              t(
                                                                context,
                                                                '已複製 Diff',
                                                                'Diff copied',
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  if (!isCopy && expandedPath && canUseDiff)
                                                    IconButton(
                                                      tooltip: t(
                                                        context,
                                                        '重新抓取',
                                                        'Refresh',
                                                      ),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      padding: EdgeInsets.zero,
                                                      constraints:
                                                          const BoxConstraints(
                                                        minWidth: 32,
                                                        minHeight: 32,
                                                      ),
                                                      icon: Icon(
                                                        Icons.refresh_rounded,
                                                        size: 18,
                                                        color: loadingPath
                                                            ? auraTokens.textMuted
                                                                .withOpacity(0.35)
                                                            : auraTokens.textMuted,
                                                      ),
                                                      onPressed: loadingPath
                                                          ? null
                                                          : () =>
                                                              _fetchDiffForPath(
                                                                path,
                                                                refresh: true,
                                                              ),
                                                    ),
                                                  Icon(
                                                    expandedPath
                                                        ? Icons.expand_less_rounded
                                                        : Icons.expand_more_rounded,
                                                    size: 20,
                                                    color: auraTokens.textMuted,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (expandedPath) ...[
                                        Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: isDark
                                              ? stitchGlassBorder
                                                  .withOpacity(0.4)
                                              : auraTokens.border
                                                  .withOpacity(0.45),
                                        ),
                                        if (isCopy)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 12),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Icon(
                                                  Icons.content_copy_rounded,
                                                  size: 15,
                                                  color: auraTokens.textSubtle,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    t(
                                                      context,
                                                      '此為 SVN 複製操作（分支建立），diff 內容可能包含整棵目錄樹，略過以避免逾時。\n'
                                                      '來源：${path.copyFromPath} @ r${path.copyFromRev ?? '-'}',
                                                      'This is an SVN copy operation (branch creation). Diff may contain the entire directory tree and is skipped to avoid timeout.\n'
                                                      'Copied from: ${path.copyFromPath} @ r${path.copyFromRev ?? '-'}',
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      height: 1.6,
                                                      color: auraTokens.textMuted,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          InlineUnifiedDiffPanel(
                                            showTitleBar: false,
                                            embeddedLoadingFixedHeight:
                                                _kEmbeddedDiffLoadingBodyHeight,
                                            diffText: cached?.diff ?? '',
                                            isLoading: loadingPath,
                                            errorText: error,
                                            onCopy: null,
                                            onRefresh: null,
                                            onOpenWindow: null,
                                          ),
                                      ],
                                    ],
                                  ),
                                ),
                                );
                              },
                            ),
                            if (commit.changedPaths.length > 30)
                              Text(
                                t(
                                  context,
                                  '另有 ${commit.changedPaths.length - 30} 筆路徑未展開',
                                  '${commit.changedPaths.length - 30} more paths are hidden',
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }
}