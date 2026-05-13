import 'dart:math' show max;
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


class TopologyCard extends StatelessWidget {
  const TopologyCard({
    required this.data,
    required this.onBranchSelected,
  });

  final AppData data;
  final ValueChanged<String> onBranchSelected;

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

    final isDark = theme.brightness == Brightness.dark;
    final panelBg = isDark ? cyberMainPanel : aura(context).surfaceAlt;

    return Material(
      color: panelBg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Transform.translate(
              offset: const Offset(0, -50),
              child: Text(
                'Topology',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -38),
                child: ListView.separated(
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
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopologyNodeTile extends StatelessWidget {
  const TopologyNodeTile({
    required this.path,
    required this.node,
    required this.selected,
    required this.onTap,
  });

  final String path;
  final BranchNode node;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = node.children;

    // 根據路徑決定左側邊框顏色
    Color accentBorderColor;
    
    if (path.startsWith('/branches')) {
      // /branches: #80678e
      accentBorderColor = const Color(0xFF80678E);
    } else if (path.startsWith('/trunk')) {
      // /trunk: #74f4fe
      accentBorderColor = const Color(0xFF74F4FE);
    } else if (path.startsWith('/tags')) {
      // /tags: #ffb4ab
      accentBorderColor = const Color(0xFFFFB4AB);
    } else {
      // 預設
      accentBorderColor = const Color(0xFF2C3333);
    }

    // 選中狀態覆蓋
    if (selected) {
      accentBorderColor = theme.colorScheme.primary.withOpacity(0.35);
    }

    final isDark = theme.brightness == Brightness.dark;
    final cardFill = isDark
        ? cyberSurfaceSoft
        : aura(context).surface;
    final hover = isDark
        ? cyberSurfaceSoft
        : aura(context).surfaceSoft;

    return ClipRRect(
      borderRadius: BorderRadius.circular(5.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: hover,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: dashboardStatStripDecoration(
              context,
              accentBorder: accentBorderColor,
            ).copyWith(
              color: cardFill,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (node.kind == 'tag')
                      Icon(
                        Icons.sell_outlined,
                        color: theme.colorScheme.primary,
                      )
                    else if (isTrunkPath(path))
                      _NarrowSolidUpTriangle(
                        color: theme.colorScheme.primary,
                      )
                    else
                      Icon(
                        Icons.call_split_rounded,
                        color: theme.colorScheme.primary,
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
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SmallChip(label: 'kind', value: node.kind ?? 'root'),
                    SmallChip(
                        label: 'origin_rev',
                        value: node.originRev?.toString() ?? '-'),
                    SmallChip(
                        label: 'parent_rev',
                        value: node.parentRev?.toString() ?? '-'),
                    SmallChip(
                        label: 'children', value: children.length.toString()),
                  ],
                ),
                if (node.parent != null) ...[
                  const SizedBox(height: 10),
                  InfoLine(label: 'parent', value: node.parent!),
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
class _NarrowSolidUpTriangle extends StatelessWidget {
  const _NarrowSolidUpTriangle({required this.color});

  final Color color;

  static const double _box = 24;
  /// 與同列 Material Icon（預設 24）視覺接近；仍略窄以保留「主幹」辨識。
  static const double _w = 9;
  static const double _h = 17;
  static const double _headH = 8;
  static const double _tailW = 3;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _box,
      height: _box,
      child: Center(
        child: CustomPaint(
          size: const Size(_w, _h),
          painter: _NarrowSolidUpTrianglePainter(
            color: color,
            headHeight: _headH,
            tailWidth: _tailW,
          ),
        ),
      ),
    );
  }
}

class _NarrowSolidUpTrianglePainter extends CustomPainter {
  _NarrowSolidUpTrianglePainter({
    required this.color,
    required this.headHeight,
    required this.tailWidth,
  });

  final Color color;
  final double headHeight;
  final double tailWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;

    final apex = Offset(size.width / 2, 0);
    final baseY = headHeight;
    final bl = Offset(0, baseY);
    final br = Offset(size.width, baseY);
    final head = Path()
      ..moveTo(apex.dx, apex.dy)
      ..lineTo(bl.dx, bl.dy)
      ..lineTo(br.dx, br.dy)
      ..close();
    canvas.drawPath(head, paint);

    final tailH = (size.height - baseY).clamp(0.0, double.infinity);
    if (tailH > 0) {
      final left = size.width / 2 - tailWidth / 2;
      canvas.drawRect(
        Rect.fromLTWH(left, baseY, tailWidth, tailH),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NarrowSolidUpTrianglePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.headHeight != headHeight ||
        oldDelegate.tailWidth != tailWidth;
  }
}

class CommitTimelineItem extends StatelessWidget {
  const CommitTimelineItem({
    required this.commit,
    required this.expanded,
    required this.onExpandToggle,
    this.repository,
    this.settings,
  });

  final CommitRecord commit;
  final bool expanded;
  final VoidCallback onExpandToggle;
  final SvnRepository? repository;
  final AppSettings? settings;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: 22,
          child: CustomPaint(
            painter: TimelineRailPainter(
              lineColor: stitchPrimaryFixed,
              nodeColor: stitchPrimaryFixed,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 28, bottom: 16),
          child: CommitTile(
            commit: commit,
            repository: repository,
            settings: settings,
            expanded: expanded,
            onExpandToggle: onExpandToggle,
          ),
        ),
      ],
    );
  }
}

class TimelineRailPainter extends CustomPainter {
  TimelineRailPainter({
    required this.lineColor,
    required this.nodeColor,
  });

  final Color lineColor;
  final Color nodeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width * 0.45;
    const nodeY = 22.0;

    final linePaint = Paint()
      ..color = lineColor.withOpacity(0.32)
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
        oldDelegate.nodeColor != nodeColor;
  }
}

class CommitTile extends StatefulWidget {
  const CommitTile({
    required this.commit,
    required this.expanded,
    required this.onExpandToggle,
    this.repository,
    this.settings,
  });

  final CommitRecord commit;
  final bool expanded;
  final VoidCallback onExpandToggle;
  final SvnRepository? repository;
  final AppSettings? settings;

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
        shouldFetch =
            !_diffResults.containsKey(key) && !_diffLoadingPaths.contains(key);
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

    return Theme(
      data: theme.copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark ? stitchGlassFill : auraTokens.surface,
                // 不可與非均勻邊框色並用 borderRadius（Flutter assert）；圓角由外層 ClipRRect 裁切。
                border: Border(
                  left: BorderSide(
                    width: hl ? 2 : 1,
                    color: hl
                        ? stitchPrimaryFixed
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
                                    children: [
                                      Text(
                                        '${commit.revision}',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: hl
                                              ? (isDark
                                                  ? stitchPrimaryFixed
                                                  : auraTokens.text)
                                              : auraTokens.textMuted,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const Spacer(),
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
                                      if (commit.ticketId.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
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
                                            commit.ticketId,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: auraTokens.violet,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
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
                                '點檔名列可展開／收合，展開後即時抓取並顯示 Diff。',
                                'Tap a file row to expand or collapse; diff is fetched when expanded.',
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

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Material(
                                        color: Colors.transparent,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 4,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: LayoutBuilder(
                                                  builder: (context, cons) {
                                                    const chipW = 28.0;
                                                    const gapAfterChip = 8.0;
                                                    const gapBeforeOpen = 6.0;
                                                    const openBtnW = 36.0;
                                                    final maxTextW = max(
                                                      48.0,
                                                      cons.maxWidth -
                                                          chipW -
                                                          gapAfterChip -
                                                          gapBeforeOpen -
                                                          openBtnW,
                                                    );
                                                    return Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        InkWell(
                                                          onTap: widget.repository ==
                                                                      null ||
                                                                  widget.settings ==
                                                                      null
                                                              ? null
                                                              : () =>
                                                                  _togglePathDiff(
                                                                    path,
                                                                  ),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Container(
                                                                width: 28,
                                                                alignment:
                                                                    Alignment
                                                                        .center,
                                                                padding:
                                                                    const EdgeInsets
                                                                        .symmetric(
                                                                  vertical: 2,
                                                                ),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: actionColor(
                                                                    path.action,
                                                                  ).withOpacity(
                                                                    0.12,
                                                                  ),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                    8,
                                                                  ),
                                                                ),
                                                                child: Text(
                                                                  path.action,
                                                                  style:
                                                                      TextStyle(
                                                                    color:
                                                                        actionColor(
                                                                      path.action,
                                                                    ),
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 8,
                                                              ),
                                                              SizedBox(
                                                                width: maxTextW,
                                                                child: Text(
                                                                  pathLabel,
                                                                  maxLines: 2,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style:
                                                                      TextStyle(
                                                                    color: theme
                                                                        .colorScheme
                                                                        .primary,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        IconButton(
                                                          tooltip: t(
                                                            context,
                                                            '獨立視窗',
                                                            'Separate window',
                                                          ),
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                          padding: EdgeInsets.zero,
                                                          constraints:
                                                              const BoxConstraints(
                                                            minWidth: 36,
                                                            minHeight: 36,
                                                          ),
                                                          icon: Icon(
                                                            Icons
                                                                .open_in_new_rounded,
                                                            size: 20,
                                                            color: widget.repository ==
                                                                        null ||
                                                                    widget.settings ==
                                                                        null
                                                                ? auraTokens
                                                                    .textMuted
                                                                    .withOpacity(
                                                                      0.35,
                                                                    )
                                                                : auraTokens
                                                                    .textMuted,
                                                          ),
                                                          onPressed: widget
                                                                          .repository ==
                                                                      null ||
                                                                  widget.settings ==
                                                                      null
                                                              ? null
                                                              : () =>
                                                                  _openStandaloneDiffWindow(
                                                                    path,
                                                                  ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: t(
                                                  context,
                                                  '展開或收合 Diff',
                                                  'Expand or collapse diff',
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                                constraints:
                                                    const BoxConstraints(
                                                  minWidth: 36,
                                                  minHeight: 36,
                                                ),
                                                icon: Icon(
                                                  expandedPath
                                                      ? Icons
                                                          .expand_less_rounded
                                                      : Icons
                                                          .expand_more_rounded,
                                                  size: 22,
                                                  color: auraTokens.textMuted,
                                                ),
                                                onPressed: widget.repository ==
                                                            null ||
                                                        widget.settings == null
                                                    ? null
                                                    : () =>
                                                        _togglePathDiff(path),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (expandedPath)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: InlineUnifiedDiffPanel(
                                            diffText: cached?.diff ?? '',
                                            isLoading: loadingPath,
                                            errorText: error,
                                            headerPath: path.path,
                                            onCopy: cached == null
                                                ? null
                                                : () {
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
                                            onRefresh: widget.repository ==
                                                        null ||
                                                    widget.settings == null
                                                ? null
                                                : () => _fetchDiffForPath(
                                                      path,
                                                      refresh: true,
                                                    ),
                                          ),
                                        ),
                                    ],
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