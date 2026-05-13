import 'package:aura_svn/diff/diff_models.dart';

List<DiffFile> parseUnifiedDiff(String diff) {
  if (diff.trim().isEmpty) {
    return const [];
  }

  final sourceLines = diff.split(RegExp(r'\r?\n'));
  final files = <DiffFile>[];
  var currentRaw = <String>[];
  var currentPath = 'Diff';

  void flush() {
    if (currentRaw.isEmpty) {
      return;
    }
    files.add(buildDiffFile(currentPath, currentRaw));
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

DiffFile buildDiffFile(String fallbackPath, List<String> rawLines) {
  var path = fallbackPath;
  for (final line in rawLines) {
    if (line.startsWith('+++ ')) {
      final parsed = cleanDiffPath(line.substring(4));
      if (parsed.isNotEmpty) {
        path = parsed;
      }
      break;
    }
  }

  final lines = <DiffLine>[];
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
      lines.add(DiffLine(kind: DiffLineKind.hunk, text: raw));
      continue;
    }

    if (raw.startsWith('+') && !raw.startsWith('+++')) {
      lines.add(
        DiffLine(kind: DiffLineKind.added, text: raw, newLine: newLine),
      );
      newLine += 1;
      additions += 1;
      continue;
    }
    if (raw.startsWith('-') && !raw.startsWith('---')) {
      lines.add(
        DiffLine(kind: DiffLineKind.removed, text: raw, oldLine: oldLine),
      );
      oldLine += 1;
      deletions += 1;
      continue;
    }
    if (raw.startsWith(' ') || raw.isEmpty) {
      lines.add(DiffLine(
        kind: DiffLineKind.context,
        text: raw,
        oldLine: oldLine,
        newLine: newLine,
      ));
      oldLine += 1;
      newLine += 1;
      continue;
    }
    lines.add(DiffLine(kind: DiffLineKind.meta, text: raw));
  }

  return DiffFile(
    path: path,
    lines: lines,
    rawText: rawLines.join('\n'),
    additions: additions,
    deletions: deletions,
  );
}

String cleanDiffPath(String value) {
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

List<DiffLineBlock> buildDiffLineBlocks(List<DiffLine> lines) {
  final blocks = <DiffLineBlock>[];
  var current = <DiffLine>[];
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
    blocks.add(DiffLineBlock(
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
    if (line.kind == DiffLineKind.meta || line.kind == DiffLineKind.hunk) {
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
