part of 'main.dart';

enum _DiffLineKind {
  added,
  removed,
  context,
  hunk,
  meta,
}

class _DiffLine {
  const _DiffLine({
    required this.kind,
    required this.text,
    this.oldLine,
    this.newLine,
  });

  final _DiffLineKind kind;
  final String text;
  final int? oldLine;
  final int? newLine;
}

class _DiffFile {
  const _DiffFile({
    required this.path,
    required this.lines,
    required this.rawText,
    required this.additions,
    required this.deletions,
  });

  final String path;
  final List<_DiffLine> lines;
  final String rawText;
  final int additions;
  final int deletions;
}

List<_DiffFile> _parseUnifiedDiff(String diff) {
  if (diff.trim().isEmpty) {
    return const [];
  }

  final sourceLines = diff.split(RegExp(r'\r?\n'));
  final files = <_DiffFile>[];
  var currentRaw = <String>[];
  var currentPath = 'Diff';

  void flush() {
    if (currentRaw.isEmpty) {
      return;
    }
    files.add(_buildDiffFile(currentPath, currentRaw));
    currentRaw = [];
  }

  for (final line in sourceLines) {
    if (line.startsWith('Index: ') && currentRaw.isNotEmpty) {
      flush();
    }
    if (line.startsWith('Index: ')) {
      currentPath = line.substring('Index: '.length).trim();
    }
    currentRaw.add(line);
  }
  flush();

  return files;
}

_DiffFile _buildDiffFile(String fallbackPath, List<String> rawLines) {
  var path = fallbackPath;
  for (final line in rawLines) {
    if (line.startsWith('+++ ')) {
      final parsed = _cleanDiffPath(line.substring(4));
      if (parsed.isNotEmpty) {
        path = parsed;
      }
      break;
    }
  }

  final lines = <_DiffLine>[];
  var oldLine = 0;
  var newLine = 0;
  var additions = 0;
  var deletions = 0;

  final hunkPattern = RegExp(r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@');
  for (final raw in rawLines) {
    final hunkMatch = hunkPattern.firstMatch(raw);
    if (hunkMatch != null) {
      oldLine = int.tryParse(hunkMatch.group(1) ?? '') ?? 0;
      newLine = int.tryParse(hunkMatch.group(2) ?? '') ?? 0;
      lines.add(_DiffLine(kind: _DiffLineKind.hunk, text: raw));
      continue;
    }

    if (raw.startsWith('+') && !raw.startsWith('+++')) {
      lines.add(
        _DiffLine(kind: _DiffLineKind.added, text: raw, newLine: newLine),
      );
      newLine += 1;
      additions += 1;
      continue;
    }
    if (raw.startsWith('-') && !raw.startsWith('---')) {
      lines.add(
        _DiffLine(kind: _DiffLineKind.removed, text: raw, oldLine: oldLine),
      );
      oldLine += 1;
      deletions += 1;
      continue;
    }
    if (raw.startsWith(' ') || raw.isEmpty) {
      lines.add(_DiffLine(
        kind: _DiffLineKind.context,
        text: raw,
        oldLine: oldLine,
        newLine: newLine,
      ));
      oldLine += 1;
      newLine += 1;
      continue;
    }
    lines.add(_DiffLine(kind: _DiffLineKind.meta, text: raw));
  }

  return _DiffFile(
    path: path,
    lines: lines,
    rawText: rawLines.join('\n'),
    additions: additions,
    deletions: deletions,
  );
}

String _cleanDiffPath(String value) {
  var text = value.trim();
  if (text.startsWith('(revision ')) {
    return '';
  }
  final tabIndex = text.indexOf('\t');
  if (tabIndex >= 0) {
    text = text.substring(0, tabIndex);
  }
  if (text.startsWith('/')) {
    return text;
  }
  return text.replaceFirst(RegExp(r'^\S+://[^/]+'), '');
}

class _UnifiedDiffViewer extends StatelessWidget {
  const _UnifiedDiffViewer({required this.files});

  final List<_DiffFile> files;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const Center(child: Text('(empty diff)'));
    }

    return ListView.separated(
      itemCount: files.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _DiffFileCard(file: files[index]),
    );
  }
}

class _DiffFileCard extends StatelessWidget {
  const _DiffFileCard({required this.file});

  final _DiffFile file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: SelectableText(
          file.path,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text('+${file.additions} -${file.deletions}'),
        trailing: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _DiffStatPill(
              text: '+${file.additions}',
              color: Colors.green,
            ),
            _DiffStatPill(
              text: '-${file.deletions}',
              color: Colors.red,
            ),
            IconButton(
              tooltip: _t(context, '複製此檔案 Diff', 'Copy this file diff'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: file.rawText));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_t(
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
          _DiffLinesTable(lines: file.lines),
        ],
      ),
    );
  }
}

class _DiffStatPill extends StatelessWidget {
  const _DiffStatPill({
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
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DiffLinesTable extends StatelessWidget {
  const _DiffLinesTable({required this.lines});

  final List<_DiffLine> lines;

  @override
  Widget build(BuildContext context) {
    final blocks = _buildDiffLineBlocks(lines);

    return SelectionArea(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              blocks.map((block) => _DiffLineBlockView(block: block)).toList(),
        ),
      ),
    );
  }
}

class _DiffLineBlock {
  const _DiffLineBlock({
    required this.lines,
    required this.oldStart,
    required this.oldEnd,
    required this.newStart,
    required this.newEnd,
  });

  final List<_DiffLine> lines;
  final int? oldStart;
  final int? oldEnd;
  final int? newStart;
  final int? newEnd;
}

List<_DiffLineBlock> _buildDiffLineBlocks(List<_DiffLine> lines) {
  final blocks = <_DiffLineBlock>[];
  var current = <_DiffLine>[];
  int? previousOld;
  int? previousNew;

  void flush() {
    if (current.isEmpty) {
      return;
    }
    final oldNumbers = current
        .map((line) => line.oldLine)
        .whereType<int>()
        .toList(growable: false);
    final newNumbers = current
        .map((line) => line.newLine)
        .whereType<int>()
        .toList(growable: false);
    blocks.add(_DiffLineBlock(
      lines: List.unmodifiable(current),
      oldStart: oldNumbers.isEmpty ? null : oldNumbers.first,
      oldEnd: oldNumbers.isEmpty ? null : oldNumbers.last,
      newStart: newNumbers.isEmpty ? null : newNumbers.first,
      newEnd: newNumbers.isEmpty ? null : newNumbers.last,
    ));
    current = [];
    previousOld = null;
    previousNew = null;
  }

  for (final line in lines) {
    if (line.kind == _DiffLineKind.meta || line.kind == _DiffLineKind.hunk) {
      flush();
      current = [line];
      flush();
      continue;
    }

    final oldContinues = line.oldLine == null ||
        previousOld == null ||
        line.oldLine == previousOld! + 1;
    final newContinues = line.newLine == null ||
        previousNew == null ||
        line.newLine == previousNew! + 1;
    if (current.isNotEmpty && (!oldContinues || !newContinues)) {
      flush();
    }

    current.add(line);
    previousOld = line.oldLine ?? previousOld;
    previousNew = line.newLine ?? previousNew;
  }
  flush();

  return blocks;
}

class _DiffLineBlockView extends StatelessWidget {
  const _DiffLineBlockView({required this.block});

  final _DiffLineBlock block;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DiffLineRange(start: block.oldStart, end: block.oldEnd),
          _DiffLineRange(start: block.newStart, end: block.newEnd),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: block.lines
                .map((line) => _DiffLineContentRow(line: line))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _DiffLineContentRow extends StatelessWidget {
  const _DiffLineContentRow({required this.line});

  final _DiffLine line;

  @override
  Widget build(BuildContext context) {
    final background = switch (line.kind) {
      _DiffLineKind.added => const Color(0xFFE6FFEC),
      _DiffLineKind.removed => const Color(0xFFFFEBE9),
      _DiffLineKind.hunk => const Color(0xFFDDF4FF),
      _DiffLineKind.meta => const Color(0xFFF6F8FA),
      _DiffLineKind.context => Colors.white,
    };
    final textColor = switch (line.kind) {
      _DiffLineKind.added => const Color(0xFF116329),
      _DiffLineKind.removed => const Color(0xFF82071E),
      _DiffLineKind.hunk => const Color(0xFF0969DA),
      _DiffLineKind.meta => const Color(0xFF57606A),
      _DiffLineKind.context => const Color(0xFF24292F),
    };
    final marker = switch (line.kind) {
      _DiffLineKind.added => '+',
      _DiffLineKind.removed => '-',
      _DiffLineKind.hunk => '@',
      _ => ' ',
    };

    return Container(
      color: background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              marker,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 900),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SelectableText(
                _displayDiffText(line.text),
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffLineRange extends StatelessWidget {
  const _DiffLineRange({
    required this.start,
    required this.end,
  });

  final int? start;
  final int? end;

  @override
  Widget build(BuildContext context) {
    final text = start == null
        ? ''
        : start == end
            ? start.toString()
            : '$start-$end';

    return Container(
      width: 70,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      color: Colors.black.withOpacity(0.03),
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: Color(0xFF6E7781),
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }
}

String _displayDiffText(String text) {
  if (text.startsWith('+') || text.startsWith('-') || text.startsWith(' ')) {
    return text.length > 1 ? text.substring(1) : '';
  }
  return text;
}