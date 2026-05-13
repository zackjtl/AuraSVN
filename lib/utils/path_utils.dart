import 'dart:io';

String joinPath(String first, String second, [String? third, String? fourth]) {
  final separator = Platform.pathSeparator;
  final segments = <String>[
    first,
    second,
    if (third != null) third,
    if (fourth != null) fourth,
  ];
  return segments.reduce(
    (a, b) => a.endsWith(separator) ? '$a$b' : '$a$separator$b',
  );
}

String fileName(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.lastIndexOf('/') + 1);
}
