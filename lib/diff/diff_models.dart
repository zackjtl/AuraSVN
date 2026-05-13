enum DiffLineKind { meta, hunk, context, added, removed }

class DiffLine {
  const DiffLine({
    required this.kind,
    required this.text,
    this.oldLine,
    this.newLine,
  });

  final DiffLineKind kind;
  final String text;
  final int? oldLine;
  final int? newLine;
}

class DiffFile {
  const DiffFile({
    required this.path,
    required this.lines,
    required this.rawText,
    required this.additions,
    required this.deletions,
  });

  final String path;
  final List<DiffLine> lines;
  final String rawText;
  final int additions;
  final int deletions;
}

class DiffLineBlock {
  const DiffLineBlock({
    required this.lines,
    required this.oldStart,
    required this.oldEnd,
    required this.newStart,
    required this.newEnd,
  });

  final List<DiffLine> lines;
  final int? oldStart;
  final int? oldEnd;
  final int? newStart;
  final int? newEnd;
}
