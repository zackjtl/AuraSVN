import 'dart:math' show max;

import 'package:aura_svn/app_theme.dart';
import 'package:aura_svn/diff/diff_models.dart';
import 'package:aura_svn/diff/diff_parser.dart';
import 'package:aura_svn/language_scope.dart';
import 'package:aura_svn/notes_store.dart';
import 'package:aura_svn/utils/helpers.dart';
import 'package:aura_svn/widgets/misc_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Diff 內文與行號共用：12px、行高 1.35、等寬、無裝飾線。
TextStyle _diffMono12(Color color, {FontWeight fontWeight = FontWeight.w400}) {
  return GoogleFonts.jetBrainsMono(
    fontSize: 12,
    height: 1.35,
    color: color,
    fontWeight: fontWeight,
    fontFeatures: const [FontFeature.tabularFigures()],
    decoration: TextDecoration.none,
    decorationThickness: 0,
  );
}
enum UnifiedDiffPresentation { standard, embedDark }

/// 內嵌 diff 在水平捲動下需估計內容最小寬度，才能讓列背景至少撐滿視窗寬。
double _estimateEmbedTableMinWidth(List<DiffLineBlock> blocks) {
  const gutterAndMarker = 140.0 + 22.0;
  const minText = 900.0;
  const approxCharPx = 7.2;
  var maxLine = minText;
  for (final block in blocks) {
    for (final line in block.lines) {
      final len = displayDiffText(line.text).length;
      maxLine = max(maxLine, len * approxCharPx + 32);
    }
  }
  return gutterAndMarker + maxLine;
}

class RevisionDiffDialog extends StatelessWidget {
  const RevisionDiffDialog({super.key, required this.result});

  final RevisionDiffResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final files = parseUnifiedDiff(result.diff);
    return Dialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(28),
      child: SizedBox(
        width: size.width * 0.9,
        height: size.height * 0.86,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        theme.colorScheme.primary.withOpacity(0.12),
                    child: Icon(
                      Icons.difference_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.path.isEmpty
                              ? '${result.repoName} r${result.revision} Diff'
                              : '${result.repoName} r${result.revision} ${t(context, '檔案 Diff', 'File Diff')}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          result.cached
                              ? t(
                                  context, '來源：本機 cache', 'Source: local cache')
                              : t(
                                  context,
                                  '來源：SVN 即時抓取',
                                  'Source: fetched from SVN',
                                ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: result.diff));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(t(context, '已複製 Diff', 'Diff copied')),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(t(context, '複製 Diff', 'Copy Diff')),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: t(context, '關閉', 'Close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (result.path.isNotEmpty) ...[
                InfoLine(label: t(context, '檔案', 'File'), value: result.path),
                const SizedBox(height: 8),
              ],
              InfoLine(label: 'Cache', value: result.cacheFile),
              const SizedBox(height: 12),
              Expanded(
                child: UnifiedDiffViewer(
                  files: files,
                  presentation: UnifiedDiffPresentation.standard,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UnifiedDiffViewer extends StatelessWidget {
  const UnifiedDiffViewer({
    super.key,
    required this.files,
    this.presentation = UnifiedDiffPresentation.standard,
  });

  final List<DiffFile> files;
  final UnifiedDiffPresentation presentation;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const Center(child: Text('(empty diff)'));
    }

    return ListView.separated(
      itemCount: files.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => DiffFileCard(
        file: files[index],
        presentation: presentation,
      ),
    );
  }
}

class DiffFileCard extends StatelessWidget {
  const DiffFileCard({
    super.key,
    required this.file,
    this.presentation = UnifiedDiffPresentation.standard,
  });

  final DiffFile file;
  final UnifiedDiffPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: _ReadOnlySelectableNoSpell(
          text: file.path,
          style: (theme.textTheme.titleSmall ?? const TextStyle()).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text('+${file.additions} -${file.deletions}'),
        trailing: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DiffStatPill(
              text: '+${file.additions}',
              color: Colors.green,
            ),
            DiffStatPill(
              text: '-${file.deletions}',
              color: Colors.red,
            ),
            IconButton(
              tooltip: t(context, '複製此檔案 Diff', 'Copy this file diff'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: file.rawText));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(t(
                      context,
                      '已複製此檔案 Diff',
                      'Copied this file diff',
                    )),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          DiffLinesTable(lines: file.lines, presentation: presentation),
        ],
      ),
    );
  }
}

class DiffStatPill extends StatelessWidget {
  const DiffStatPill({
    super.key,
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class DiffLinesTable extends StatelessWidget {
  const DiffLinesTable({
    super.key,
    required this.lines,
    this.presentation = UnifiedDiffPresentation.standard,
  });

  final List<DiffLine> lines;
  final UnifiedDiffPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final blocks = buildDiffLineBlocks(lines);

    return SelectionArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final vp = constraints.maxWidth;
          final vpSafe = vp.isFinite && vp > 0 ? vp : 0.0;
          final contentMin = _estimateEmbedTableMinWidth(blocks);
          final tableW = max(vpSafe, contentMin);

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableW,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: blocks
                    .map(
                      (block) => DiffLineBlockView(
                        block: block,
                        presentation: presentation,
                        fullWidthLineBackground: true,
                      ),
                    )
                    .toList(),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 只讀、可選取複製；關閉原生拼字底線（Windows 上 [SelectableText] 仍會走拼字服務）。
class _ReadOnlySelectableNoSpell extends StatefulWidget {
  const _ReadOnlySelectableNoSpell({
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  State<_ReadOnlySelectableNoSpell> createState() =>
      _ReadOnlySelectableNoSpellState();
}

class _ReadOnlySelectableNoSpellState extends State<_ReadOnlySelectableNoSpell> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
    _focusNode = FocusNode(canRequestFocus: false, skipTraversal: true);
  }

  @override
  void didUpdateWidget(covariant _ReadOnlySelectableNoSpell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text && _controller.text != widget.text) {
      _controller.value = TextEditingValue(
        text: widget.text,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectionColor = theme.textSelectionTheme.selectionColor ??
        theme.colorScheme.primary.withOpacity(0.28);

    return EditableText(
      controller: _controller,
      focusNode: _focusNode,
      readOnly: true,
      autocorrect: false,
      enableSuggestions: false,
      style: widget.style,
      strutStyle: StrutStyle.fromTextStyle(widget.style, forceStrutHeight: true),
      cursorColor: Colors.transparent,
      backgroundCursorColor: Colors.transparent,
      showCursor: false,
      enableInteractiveSelection: true,
      maxLines: null,
      selectionControls: desktopTextSelectionHandleControls,
      spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
      magnifierConfiguration: TextMagnifierConfiguration.disabled,
      selectionColor: selectionColor,
    );
  }
}

class DiffLineBlockView extends StatelessWidget {
  const DiffLineBlockView({
    super.key,
    required this.block,
    this.presentation = UnifiedDiffPresentation.standard,
    this.fullWidthLineBackground = false,
  });

  final DiffLineBlock block;
  final UnifiedDiffPresentation presentation;
  /// 為 true 時，內文欄以 [Expanded] 撐滿表格寬，列底色可延伸至視窗右緣。
  final bool fullWidthLineBackground;

  @override
  Widget build(BuildContext context) {
    final lineColumn = Column(
      crossAxisAlignment: fullWidthLineBackground
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: block.lines
          .map(
            (line) => DiffLineContentRow(
              line: line,
              presentation: presentation,
              fullWidthBackground: fullWidthLineBackground,
            ),
          )
          .toList(),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DiffLineRange(
            start: block.oldStart,
            end: block.oldEnd,
            presentation: presentation,
          ),
          DiffLineRange(
            start: block.newStart,
            end: block.newEnd,
            presentation: presentation,
          ),
          if (fullWidthLineBackground)
            Expanded(child: lineColumn)
          else
            lineColumn,
        ],
      ),
    );
  }
}

class DiffLineContentRow extends StatelessWidget {
  const DiffLineContentRow({
    super.key,
    required this.line,
    this.presentation = UnifiedDiffPresentation.standard,
    this.fullWidthBackground = false,
  });

  final DiffLine line;
  final UnifiedDiffPresentation presentation;
  final bool fullWidthBackground;

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color textColor;
    switch (presentation) {
      case UnifiedDiffPresentation.standard:
        background = switch (line.kind) {
          DiffLineKind.added => const Color(0xFFE6FFEC),
          DiffLineKind.removed => const Color(0xFFFFEBE9),
          DiffLineKind.hunk => const Color(0xFFDDF4FF),
          DiffLineKind.meta => const Color(0xFFF6F8FA),
          DiffLineKind.context => const Color(0xFFF8FAFC),
        };
        textColor = switch (line.kind) {
          DiffLineKind.added => const Color(0xFF116329),
          DiffLineKind.removed => const Color(0xFF82071E),
          DiffLineKind.hunk => const Color(0xFF0969DA),
          DiffLineKind.meta => const Color(0xFF57606A),
          DiffLineKind.context => const Color(0xFF1E293B),
        };
      case UnifiedDiffPresentation.embedDark:
        background = switch (line.kind) {
          DiffLineKind.added => const Color(0xFF0A2F2C),
          DiffLineKind.removed => const Color(0xFF2D1B1E),
          DiffLineKind.hunk => const Color(0xFF1A2332),
          DiffLineKind.meta => const Color(0xFF161B22),
          DiffLineKind.context => Colors.transparent,
        };
        textColor = switch (line.kind) {
          DiffLineKind.added => const Color(0xFF56D4D0),
          DiffLineKind.removed => const Color(0xFFFF9B9B),
          DiffLineKind.hunk => const Color(0xFF79C0FF),
          DiffLineKind.meta => const Color(0xFF8B949E),
          DiffLineKind.context => const Color(0xFFE6EDF3),
        };
    }
    final marker = switch (line.kind) {
      DiffLineKind.added => '+',
      DiffLineKind.removed => '-',
      DiffLineKind.hunk => '@',
      _ => ' ',
    };

    final leftAccent = presentation == UnifiedDiffPresentation.embedDark &&
            line.kind == DiffLineKind.added
        ? const Border(
            left: BorderSide(color: Color(0xFF3EDDDA), width: 3),
          )
        : null;

    final textStyle = _diffMono12(textColor);
    final textWidget = _ReadOnlySelectableNoSpell(
      text: displayDiffText(line.text),
      style: textStyle,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: leftAccent,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              marker,
              textAlign: TextAlign.center,
              style: textStyle.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (fullWidthBackground)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: textWidget,
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 900),
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: textWidget,
              ),
            ),
        ],
      ),
    );
  }
}

class DiffLineRange extends StatelessWidget {
  const DiffLineRange({
    super.key,
    required this.start,
    required this.end,
    this.presentation = UnifiedDiffPresentation.standard,
  });

  final int? start;
  final int? end;
  final UnifiedDiffPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final text = start == null
        ? ''
        : start == end
            ? start.toString()
            : '$start-$end';

    final gutterColor = presentation == UnifiedDiffPresentation.embedDark
        ? const Color(0xFF21262D)
        : const Color(0xFFE2E8F0);
    final textColor = presentation == UnifiedDiffPresentation.embedDark
        ? const Color(0xFF8B949E)
        : const Color(0xFF6E7781);

    return Container(
      width: 70,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      color: gutterColor,
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: _diffMono12(textColor),
      ),
    );
  }
}

/// 內嵌於列表的 diff：外層透明、圓角 10、淺色邊框；內容為暗色對比列。
class InlineUnifiedDiffPanel extends StatefulWidget {
  const InlineUnifiedDiffPanel({
    super.key,
    required this.diffText,
    required this.isLoading,
    this.errorText,
    this.headerPath,
    this.onCopy,
    this.onRefresh,
    this.onOpenWindow,
    this.fillAvailableHeight = false,
    /// 為 false 時不顯示頂部檔名工具列（由外層標題列擔任），僅顯示 diff 內容區。
    this.showTitleBar = true,
    /// 內嵌且 [showTitleBar] 為 false 時，載入中先佔用的固定高度（像素）；null 則沿用內建 padding。
    this.embeddedLoadingFixedHeight,
  });

  final String diffText;
  final bool isLoading;
  final String? errorText;
  final String? headerPath;
  final VoidCallback? onCopy;
  final VoidCallback? onRefresh;
  final VoidCallback? onOpenWindow;
  /// 為 true 時父層須給固定高度，diff 捲動區以 [Expanded] 佔滿剩餘（父層多為依視窗比例的 [SizedBox]）。
  final bool fillAvailableHeight;
  final bool showTitleBar;
  final double? embeddedLoadingFixedHeight;

  @override
  State<InlineUnifiedDiffPanel> createState() => _InlineUnifiedDiffPanelState();
}

class _InlineUnifiedDiffPanelState extends State<InlineUnifiedDiffPanel> {
  late final ScrollController _bodyScrollController;

  Color _panelBorder(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.light) {
      return aura(context).border;
    }
    return const Color(0xFF3D4A4D);
  }

  @override
  void initState() {
    super.initState();
    _bodyScrollController = ScrollController();
  }

  @override
  void dispose() {
    _bodyScrollController.dispose();
    super.dispose();
  }

  Widget _diffScrollBody(List<DiffFile> files, ThemeData theme) {
    final presentation = theme.brightness == Brightness.dark
        ? UnifiedDiffPresentation.embedDark
        : UnifiedDiffPresentation.standard;
    return Scrollbar(
      controller: _bodyScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _bodyScrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < files.length; i++) ...[
              if (files.length > 1)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    i == 0 ? 8 : 16,
                    12,
                    6,
                  ),
                  child: Text(
                    files[i].path,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              DiffLinesTable(
                lines: files[i].lines,
                presentation: presentation,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final files = parseUnifiedDiff(widget.diffText);
    final fill = widget.fillAvailableHeight;

    final header = Material(
      color: theme.brightness == Brightness.dark
          ? Colors.transparent
          : aura(context).surfaceAlt,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              size: 18,
              color: theme.colorScheme.onSurface.withOpacity(0.65),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.headerPath ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jetBrainsMono(
                        textStyle: theme.textTheme.bodySmall,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [
                          FontFeature.tabularFigures(),
                        ],
                        decoration: TextDecoration.none,
                        decorationThickness: 0,
                      ),
                    ),
                  ),
                  if (widget.onOpenWindow != null) ...[
                    const SizedBox(width: 2),
                    IconButton(
                      tooltip: t(context, '獨立視窗', 'Separate window'),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      icon: Icon(
                        Icons.open_in_new_rounded,
                        size: 12,
                        color: aura(context).textMuted.withOpacity(0.55),
                      ),
                      onPressed: widget.onOpenWindow,
                    ),
                  ],
                ],
              ),
            ),
            if (widget.onCopy != null)
              IconButton(
                tooltip: t(context, '複製 Diff', 'Copy Diff'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_rounded, size: 18),
                onPressed: widget.onCopy,
              ),
            if (widget.onRefresh != null)
              IconButton(
                tooltip: t(context, '重新抓取', 'Refresh'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                onPressed: widget.onRefresh,
              ),
          ],
        ),
      ),
    );

    final borderColor = _panelBorder(context);
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: theme.brightness == Brightness.light
          ? borderColor
          : borderColor.withOpacity(0.35),
    );

    late final List<Widget> bodyChildren;
    if (widget.isLoading) {
      final fixedH = widget.embeddedLoadingFixedHeight;
      if (!fill &&
          fixedH != null &&
          fixedH > 0 &&
          !widget.showTitleBar) {
        bodyChildren = [
          SizedBox(
            height: fixedH,
            width: double.infinity,
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ];
      } else if (fill) {
        bodyChildren = [
          const Expanded(
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ];
      } else {
        bodyChildren = [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ];
      }
    } else if (widget.errorText != null) {
      final errorChild = Padding(
        padding: const EdgeInsets.all(12),
        child: _ReadOnlySelectableNoSpell(
          text: widget.errorText!,
          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      );
      bodyChildren = [
        fill
            ? Expanded(
                child: SingleChildScrollView(child: errorChild),
              )
            : errorChild,
      ];
    } else if (files.isEmpty) {
      bodyChildren = [
        fill
            ? Expanded(
                child: Center(
                  child: Text(
                    '(empty diff)',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  '(empty diff)',
                  style: theme.textTheme.bodySmall,
                ),
              ),
      ];
    } else {
      final scroll = _diffScrollBody(files, theme);
      bodyChildren = [
        fill
            ? Expanded(child: scroll)
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: scroll,
              ),
      ];
    }

    if (!widget.showTitleBar) {
      return ClipRRect(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
          children: bodyChildren,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.brightness == Brightness.light
              ? borderColor
              : borderColor.withOpacity(0.55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          header,
          divider,
          ...bodyChildren,
        ],
      ),
    );
  }
}
