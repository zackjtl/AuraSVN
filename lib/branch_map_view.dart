import 'package:aura_svn/app_theme.dart';
import 'package:aura_svn/branch_map_edge_renderer.dart';
import 'package:aura_svn/branch_map_painter.dart';
import 'package:aura_svn/language_scope.dart';
import 'package:aura_svn/models/app_data.dart';
import 'package:aura_svn/models/branch_node.dart';
import 'package:aura_svn/models/commit_record.dart';
import 'package:aura_svn/models/svn_repository.dart';
import 'package:aura_svn/notes_store.dart';
import 'package:aura_svn/utils/branch_paths.dart';
import 'package:aura_svn/widgets/markdown_styles.dart';
import 'package:aura_svn/widgets/misc_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:graphview/GraphView.dart' as graphview;

class BranchMapView extends StatefulWidget {
  const BranchMapView({
    super.key,
    required this.repository,
    required this.data,
    required this.settings,
    this.onBranchSelected,
  });

  final SvnRepository repository;
  final AppData data;
  final AppSettings settings;
  final ValueChanged<String>? onBranchSelected;

  @override
  State<BranchMapView> createState() => _BranchMapViewState();
}

class _BranchMapViewState extends State<BranchMapView> {
  final TransformationController _transformationController =
      TransformationController();

  late BranchGraphModel _model;

  @override
  void initState() {
    super.initState();
    _model = BranchGraphModel.fromData(widget.data);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusPath(_model.latestBranchPath ?? _model.rootPath, scale: 0.85);
    });
  }

  @override
  void didUpdateWidget(covariant BranchMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _model = BranchGraphModel.fromData(widget.data);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusPath(_model.latestBranchPath ?? _model.rootPath, scale: 0.85);
      });
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  void _goToTrunk() {
    _focusPath(_model.rootPath, scale: 0.9);
  }

  void _focusPath(String? path, {double scale = 0.9}) {
    if (!mounted || path == null) {
      return;
    }

    final viewport = context.size ?? const Size(1000, 700);
    final depth = _model.depthFor(path);
    final index = _model.orderFor(path);
    final targetX = 140.0 + index * 250.0;
    final targetY = 120.0 + depth * 180.0;
    final center = Offset(viewport.width / 2, viewport.height / 2);
    _transformationController.value = Matrix4.identity()
      ..translate(center.dx - targetX * scale, center.dy - targetY * scale, 0)
      ..scale(scale);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_model.paths.isEmpty) {
      return const EmptyDataCard();
    }

    final mapBg = theme.brightness == Brightness.dark
        ? cyberMainPanel
        : aura(context).surfaceAlt;

    return Material(
      color: mapBg,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BranchMapBackgroundPainter(colors: aura(context)),
            ),
          ),
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transformationController,
              constrained: false,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              minScale: 0.1,
              maxScale: 2.5,
              child: Padding(
                padding: const EdgeInsets.all(80),
                child: graphview.GraphView(
                  graph: _model.graph,
                  algorithm: graphview.BuchheimWalkerAlgorithm(
                    _model.configuration,
                    SmoothTreeEdgeRenderer(_model.configuration),
                  ),
                  paint: Paint()
                    ..color = const Color(0xFF94A3B8)
                    ..strokeWidth = 1.6
                    ..style = PaintingStyle.stroke
                    ..strokeJoin = StrokeJoin.round,
                  animated: false,
                  builder: (node) {
                    final path = node.key?.value.toString() ?? '';
                    final branch = _model.nodeFor(path);
                    return BranchMapNode(
                      path: path,
                      node: branch,
                      isRoot: isTrunkPath(path),
                      commitCount: filterCommitsForBranch(
                        widget.data,
                        path,
                        branch,
                      ).length,
                      onTap: () {
                        final onBranchSelected = widget.onBranchSelected;
                        if (onBranchSelected != null) {
                          onBranchSelected(path);
                        } else {
                          _showBranchLog(path, branch);
                        }
                      },
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            top: 18,
            left: 18,
            child: BranchMapTitle(
              repository: widget.repository,
              nodeCount: _model.paths.length,
              latestPath: _model.latestBranchPath,
            ),
          ),
          Positioned(
            right: 18,
            bottom: 18,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'reset-zoom-${widget.repository.name}',
                  tooltip: t(context, '重置縮放', 'Reset Zoom'),
                  onPressed: _resetZoom,
                  child: const Icon(Icons.center_focus_strong_rounded),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'go-trunk-${widget.repository.name}',
                  tooltip: t(context, '回到主線', 'Go to Trunk'),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  onPressed: _goToTrunk,
                  child: const Icon(Icons.alt_route_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBranchLog(String path, BranchNode? node) {
    final commits = filterCommitsForBranch(widget.data, path, node);
    final languageCode = LanguageScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      builder: (context) {
        return LanguageScope(
          languageCode: languageCode,
          child: BranchLogSheet(
            repository: widget.repository,
            settings: widget.settings,
            path: path,
            node: node,
            commits: commits,
          ),
        );
      },
    );
  }
}

class BranchGraphModel {
  BranchGraphModel({
    required this.graph,
    required this.configuration,
    required this.paths,
    required this.rootPath,
    required this.latestBranchPath,
    required Map<String, BranchNode> nodes,
    required Map<String, int> depths,
    required Map<String, int> orders,
  })  : _nodes = nodes,
        _depths = depths,
        _orders = orders;

  factory BranchGraphModel.fromData(AppData data) {
    final allPaths = <String>{};
    final childrenByParent = <String, Set<String>>{};
    final parentByChild = <String, String>{};

    for (final entry in data.topology.entries) {
      allPaths.add(entry.key);
      final node = entry.value;
      if (node.parent != null && node.parent!.isNotEmpty) {
        allPaths.add(node.parent!);
        parentByChild[entry.key] = node.parent!;
        childrenByParent.putIfAbsent(node.parent!, () => {}).add(entry.key);
      }
      for (final child in node.children) {
        allPaths.add(child);
        parentByChild[child] = entry.key;
        childrenByParent.putIfAbsent(entry.key, () => {}).add(child);
      }
    }

    final rootPath = pickRootPath(allPaths, parentByChild);
    if (rootPath != null) {
      allPaths.add(rootPath);
      final orphanRoots = allPaths
          .where(
            (path) => path != rootPath && !parentByChild.containsKey(path),
          )
          .toList()
        ..sort();
      for (final orphanRoot in orphanRoots) {
        parentByChild[orphanRoot] = rootPath;
        childrenByParent.putIfAbsent(rootPath, () => {}).add(orphanRoot);
      }
    }

    final graph = graphview.Graph()..isTree = true;
    final nodes = <String, graphview.Node>{};
    for (final path in allPaths) {
      nodes[path] = graphview.Node.Id(path);
      graph.addNode(nodes[path]!);
    }

    final edgePaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    for (final entry in parentByChild.entries) {
      final parent = nodes[entry.value];
      final child = nodes[entry.key];
      if (parent != null && child != null && parent != child) {
        graph.addEdge(parent, child, paint: edgePaint);
      }
    }

    final depths = <String, int>{};
    final orders = <String, int>{};
    var order = 0;
    void walk(String path, int depth, Set<String> seen) {
      if (!seen.add(path)) {
        return;
      }
      depths[path] = depth;
      orders[path] = order;
      order += 1;
      final children = (childrenByParent[path]?.toList() ?? [])
        ..sort((a, b) => a.compareTo(b));
      for (final child in children) {
        walk(child, depth + 1, seen);
      }
    }

    if (rootPath != null) {
      walk(rootPath, 0, <String>{});
    }
    for (final path in allPaths.toList()..sort()) {
      if (!orders.containsKey(path)) {
        walk(path, 0, <String>{});
      }
    }

    final latestBranchPath = data.topology.entries
        .where((entry) => !isTrunkPath(entry.key))
        .fold<MapEntry<String, BranchNode>?>(
      null,
      (latest, entry) {
        final rev = entry.value.originRev ?? -1;
        final latestRev = latest?.value.originRev ?? -1;
        return rev > latestRev ? entry : latest;
      },
    )?.key;

    final configuration = graphview.BuchheimWalkerConfiguration()
      ..siblingSeparation = 64
      ..levelSeparation = 110
      ..subtreeSeparation = 56
      ..orientation =
          graphview.BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;

    return BranchGraphModel(
      graph: graph,
      configuration: configuration,
      paths: allPaths.toList()..sort(),
      rootPath: rootPath,
      latestBranchPath: latestBranchPath,
      nodes: data.topology,
      depths: depths,
      orders: orders,
    );
  }

  final graphview.Graph graph;
  final graphview.BuchheimWalkerConfiguration configuration;
  final List<String> paths;
  final String? rootPath;
  final String? latestBranchPath;
  final Map<String, BranchNode> _nodes;
  final Map<String, int> _depths;
  final Map<String, int> _orders;

  BranchNode? nodeFor(String path) => _nodes[path];

  int depthFor(String path) => _depths[path] ?? 0;

  int orderFor(String path) => _orders[path] ?? 0;
}

class BranchMapNode extends StatelessWidget {
  const BranchMapNode({
    required this.path,
    required this.node,
    required this.isRoot,
    required this.commitCount,
    required this.onTap,
  });

  final String path;
  final BranchNode? node;
  final bool isRoot;
  final int commitCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auraTokens = aura(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isRoot
        ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF))
        : auraTokens.surfaceAlt;
    final textColor = isRoot
        ? (isDark ? Colors.white : const Color(0xFF1E3A8A))
        : auraTokens.text;
    final borderColor = isRoot
        ? (isDark ? const Color(0xFF1D4ED8) : const Color(0xFF2563EB))
        : auraTokens.accent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 190,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.10 : 0.06),
                blurRadius: isDark ? 16 : 12,
                offset: Offset(0, isDark ? 8 : 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    isRoot
                        ? Icons.account_tree_rounded
                        : Icons.call_split_rounded,
                    size: 18,
                    color: isRoot
                        ? (isDark
                            ? Colors.white
                            : theme.colorScheme.primary)
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mapBranchName(path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                path,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor.withOpacity(isRoot ? 0.78 : 0.58),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  MapNodeChip(
                    text: 'origin r${node?.originRev?.toString() ?? '-'}',
                    isRoot: isRoot,
                  ),
                  MapNodeChip(
                    text: '$commitCount commits',
                    isRoot: isRoot,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MapNodeChip extends StatelessWidget {
  const MapNodeChip({
    required this.text,
    required this.isRoot,
  });

  final String text;
  final bool isRoot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isRoot
            ? (isDark
                ? Colors.white.withOpacity(0.15)
                : aura(context).surface)
            : aura(context).surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isRoot
              ? (isDark ? Colors.white : aura(context).textMuted)
              : aura(context).textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class BranchMapTitle extends StatelessWidget {
  const BranchMapTitle({
    required this.repository,
    required this.nodeCount,
    required this.latestPath,
  });

  final SvnRepository repository;
  final int nodeCount;
  final String? latestPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = aura(context);
    final isDark = theme.brightness == Brightness.dark;
    final fillOpacity = isDark ? 0.78 : 0.86;
    final borderOpacity = isDark ? 0.55 : 0.62;

    return Container(
      width: 340,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: a.surface.withOpacity(fillOpacity),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: a.border.withOpacity(borderOpacity)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.12 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t(
              context,
              '${repository.name} · $nodeCount 個節點',
              '${repository.name} · $nodeCount nodes',
            ),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.primary),
          ),
          if (latestPath != null) ...[
            const SizedBox(height: 8),
            Text(
              t(
                context,
                '自動聚焦最新分支：${mapBranchName(latestPath!)}',
                'Auto-focused latest branch: ${mapBranchName(latestPath!)}',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: aura(context).textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class BranchLogSheet extends StatelessWidget {
  const BranchLogSheet({
    required this.repository,
    required this.settings,
    required this.path,
    required this.node,
    required this.commits,
  });

  final SvnRepository repository;
  final AppSettings settings;
  final String path;
  final BranchNode? node;
  final List<CommitRecord> commits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                child: Icon(
                  isTrunkPath(path)
                      ? Icons.account_tree_rounded
                      : Icons.call_split_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mapBranchName(path),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SelectableText(path),
                  ],
                ),
              ),
              Chip(
                label: Text('${commits.length} commits'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SmallChip(
                label: 'origin_rev',
                value: node?.originRev?.toString() ?? '-',
              ),
              SmallChip(
                label: 'parent_rev',
                value: node?.parentRev?.toString() ?? '-',
              ),
              SmallChip(label: 'kind', value: node?.kind ?? 'root'),
            ],
          ),
          const SizedBox(height: 16),
          BranchNoteEditor(
            repository: repository,
            settings: settings,
            branchPath: path,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: commits.isEmpty
                ? Center(
                    child: Text(t(
                      context,
                      '找不到此分支路徑相關的 commit。',
                      'No commits found for this branch path.',
                    )),
                  )
                : ListView.separated(
                    itemCount: commits.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final commit = commits[index];
                      return _BranchLogTile(commit: commit, branchPath: path);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class BranchNoteEditor extends StatefulWidget {
  const BranchNoteEditor({
    super.key,
    required this.repository,
    required this.settings,
    required this.branchPath,
    this.expanded = false,
  });

  final SvnRepository repository;
  final AppSettings settings;
  final String branchPath;
  final bool expanded;

  @override
  State<BranchNoteEditor> createState() => _BranchNoteEditorState();
}

enum _MarkdownNoteMode { both, edit, preview }

class _BranchNoteEditorState extends State<BranchNoteEditor> {
  final _controller = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  _MarkdownNoteMode _mode = _MarkdownNoteMode.both;
  String? _noteFile;
  String? _status;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_refreshPreview);
    _load();
  }

  @override
  void didUpdateWidget(covariant BranchNoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.branchPath != widget.branchPath ||
        oldWidget.settings.notesRootPath != widget.settings.notesRootPath) {
      _load();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_refreshPreview);
    _controller.dispose();
    super.dispose();
  }

  void _refreshPreview() {
    if (_mode != _MarkdownNoteMode.edit && mounted) {
      setState(() {});
    }
  }

  Future<void> _load() async {
    if (widget.settings.notesRootPath.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _error = '請先到設定頁指定 Markdown 筆記根目錄。';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _status = null;
    });

    try {
      final note = await loadBranchNote(
        settings: widget.settings,
        repository: widget.repository,
        branchPath: widget.branchPath,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _controller.text = note.content;
        _noteFile = note.noteFile;
        _status = note.updatedAt == null
            ? '尚未建立筆記，儲存後會寫入共享目錄。'
            : '上次更新：${note.updatedAt!.toLocal()}';
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final note = await saveBranchNote(
        settings: widget.settings,
        repository: widget.repository,
        branchPath: widget.branchPath,
        content: _controller.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _noteFile = note.noteFile;
        _status = '已儲存：${note.updatedAt!.toLocal()}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: aura(context).surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: aura(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                t(context, 'Markdown 筆記', 'Markdown Note'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              SegmentedButton<_MarkdownNoteMode>(
                segments: [
                  ButtonSegment(
                    value: _MarkdownNoteMode.both,
                    label: Text(t(context, '雙欄', 'Both')),
                  ),
                  ButtonSegment(
                    value: _MarkdownNoteMode.edit,
                    label: Text(t(context, '編輯', 'Edit')),
                  ),
                  ButtonSegment(
                    value: _MarkdownNoteMode.preview,
                    label: Text(t(context, '預覽', 'Preview')),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: _isLoading
                    ? null
                    : (selection) {
                        setState(() {
                          _mode = selection.first;
                        });
                      },
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _isLoading || _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _isSaving
                      ? t(context, '儲存中', 'Saving')
                      : t(context, '儲存筆記', 'Save Note'),
                ),
              ),
            ],
          ),
          if (_noteFile != null) ...[
            const SizedBox(height: 8),
            InfoLine(label: t(context, '檔案', 'File'), value: _noteFile!),
          ],
          if (_status != null) ...[
            const SizedBox(height: 8),
            Text(
              _localizedBranchNoteStatus(context, _status!),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: aura(context).textMuted),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(t(context, '重試', 'Retry')),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (widget.expanded)
            Expanded(child: _buildEditorBody())
          else
            SizedBox(height: 180, child: _buildEditorBody()),
        ],
      ),
    );
  }

  Widget _buildEditorBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final editor = TextField(
      controller: _controller,
      expands: true,
      maxLines: null,
      minLines: null,
      keyboardType: TextInputType.multiline,
      textAlignVertical: TextAlignVertical.top,
      decoration: InputDecoration(
        hintText: t(
          context,
          '在這裡撰寫此分支的 Markdown 筆記...',
          'Write Markdown notes for this branch here...',
        ),
        alignLabelWithHint: true,
      ),
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
      ),
    );

    final preview = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: aura(context).surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: aura(context).border),
      ),
      child: Markdown(
        data: _controller.text,
        selectable: true,
        padding: const EdgeInsets.all(14),
        styleSheet: auraMarkdownStyle(context),
      ),
    );

    if (_mode == _MarkdownNoteMode.edit) {
      return editor;
    }
    if (_mode == _MarkdownNoteMode.preview) {
      return preview;
    }
    return Row(
      children: [
        Expanded(child: editor),
        const SizedBox(width: 12),
        Expanded(child: preview),
      ],
    );
  }
}

String _localizedBranchNoteStatus(BuildContext context, String status) {
  if (LanguageScope.of(context) != 'en') {
    return status;
  }
  if (status == '尚未建立筆記，儲存後會寫入共享目錄。') {
    return 'No note yet. Saving will write it to the shared directory.';
  }
  if (status.startsWith('上次更新：')) {
    return 'Last updated: ${status.substring('上次更新：'.length)}';
  }
  if (status.startsWith('已儲存：')) {
    return 'Saved: ${status.substring('已儲存：'.length)}';
  }
  return status;
}

class _BranchLogTile extends StatelessWidget {
  const _BranchLogTile({
    required this.commit,
    required this.branchPath,
  });

  final CommitRecord commit;
  final String branchPath;

  @override
  Widget build(BuildContext context) {
    final matchedPaths = commit.changedPaths
        .where((path) =>
            path.path.contains(branchPath) ||
            (path.copyFromPath?.contains(branchPath) ?? false))
        .toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: aura(context).surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: aura(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                child: Text(
                  commit.revision.toString(),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  commit.message.isEmpty ? '(no message)' : commit.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SmallChip(label: 'revision', value: commit.revision.toString()),
              SmallChip(label: 'author', value: commit.author),
              SmallChip(
                label: 'ticket',
                value: commit.ticketId.isEmpty ? '-' : commit.ticketId,
              ),
              SmallChip(label: 'date', value: commit.date),
            ],
          ),
          if (matchedPaths.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...matchedPaths.take(4).map(
                  (path) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${path.action} ${path.path}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

List<CommitRecord> filterCommitsForBranch(
  AppData data,
  String branchPath,
  BranchNode? node,
) {
  final originRev = node?.originRev ?? 0;
  final result = <CommitRecord>[];
  for (final commit in data.commits) {
    if (commit.revision < originRev) {
      continue;
    }
    final matched = commit.changedPaths.any(
      (path) =>
          path.path.contains(branchPath) ||
          (path.copyFromPath?.contains(branchPath) ?? false),
    );
    if (matched) {
      result.add(commit);
    }
  }
  result.sort((a, b) => b.revision.compareTo(a.revision));
  return result;
}

String? pickRootPath(Set<String> paths, Map<String, String> parentByChild) {
  final parentless = paths.where((path) => !parentByChild.containsKey(path));
  final trunk = parentless.where(isTrunkPath).toList()..sort();
  if (trunk.isNotEmpty) {
    return trunk.first;
  }
  final anyTrunk = paths.where(isTrunkPath).toList()..sort();
  if (anyTrunk.isNotEmpty) {
    return anyTrunk.first;
  }
  final fallback = parentless.toList()..sort();
  return fallback.isEmpty ? null : fallback.first;
}


String mapBranchName(String path) {
  final parts = path.split('/').where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) {
    return path;
  }
  if (parts.length >= 2 && parts[parts.length - 2] == 'branches') {
    return parts.last;
  }
  if (parts.length >= 2 && parts[parts.length - 2] == 'tags') {
    return parts.last;
  }
  return parts.last;
}
