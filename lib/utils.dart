import 'dart:convert';
import 'dart:io';

String _joinPath(String first, String second) {
  final separator = Platform.pathSeparator;
  if (first.endsWith(separator)) {
    return '$first$second';
  }
  return '$first$separator$second';
}

String _fileName(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.substring(normalized.lastIndexOf('/') + 1);
}

List<String> _splitCommandLine(String command) {
  final parts = <String>[];
  final current = StringBuffer();
  var inSingleQuote = false;
  var inDoubleQuote = false;

  for (var i = 0; i < command.length; i += 1) {
    final char = command[i];
    if (char == "'" && !inDoubleQuote) {
      inSingleQuote = !inSingleQuote;
      continue;
    }
    if (char == '"' && !inSingleQuote) {
      inDoubleQuote = !inDoubleQuote;
      continue;
    }
    if (char.trim().isEmpty && !inSingleQuote && !inDoubleQuote) {
      if (current.isNotEmpty) {
        parts.add(current.toString());
        current.clear();
      }
      continue;
    }
    current.write(char);
  }

  if (current.isNotEmpty) {
    parts.add(current.toString());
  }
  return parts;
}

List<List<String>> _parseCsv(String source) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < source.length; i += 1) {
    final char = source[i];
    if (char == '"') {
      final nextIsQuote = i + 1 < source.length && source[i + 1] == '"';
      if (inQuotes && nextIsQuote) {
        cell.write('"');
        i += 1;
      } else {
        inQuotes = !inQuotes;
      }
      continue;
    }
    if (char == ',' && !inQuotes) {
      row.add(cell.toString());
      cell.clear();
      continue;
    }
    if ((char == '\n' || char == '\r') && !inQuotes) {
      if (char == '\r' && i + 1 < source.length && source[i + 1] == '\n') {
        i += 1;
      }
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
      continue;
    }
    cell.write(char);
  }

  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}

Future<Directory> _findProjectRoot() async {
  var directory = Directory.current.absolute;
  for (var i = 0; i < 8; i += 1) {
    final marker = File(_joinPath(directory.path, 'scripts', 'svn_to_ai_loader.py'));
    if (await marker.exists()) {
      return directory;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) {
      break;
    }
    directory = parent;
  }
  throw Exception('找不到 svn_to_ai_loader.py，請從 AuraSVN 專案內啟動 Flutter UI。');
}

Future<AppData> _readOutput(
  Directory root,
  SvnRepository repository,
) async {
  final outputDir = Directory(
    _joinPath(_joinPath(root.path, 'svn_ai_output'), repository.name),
  );
  if (!await outputDir.exists()) {
    return AppData.empty();
  }

  final topology = <String, BranchNode>{};
  final topologyFile = File(_joinPath(outputDir.path, 'branch_topology.json'));
  if (await topologyFile.exists()) {
    final decoded = jsonDecode(await topologyFile.readAsString());
    if (decoded is Map<String, dynamic>) {
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          topology[entry.key] = BranchNode.fromJson(value);
        }
      }
    }
  }

  final commits = <CommitRecord>[];
  final shardNames = <String>[];
  final shardPattern = RegExp(r'^commits_\d{4}_H[12]\.csv$');
  await for (final entity in outputDir.list()) {
    if (entity is! File) {
      continue;
    }
    final name = _fileName(entity.path);
    if (!shardPattern.hasMatch(name)) {
      continue;
    }
    shardNames.add(name);
    commits.addAll(await _readCommitCsv(entity));
  }

  commits.sort((a, b) => b.revision.compareTo(a.revision));
  shardNames.sort();

  return AppData(
    topology: topology,
    commits: commits,
    shardNames: shardNames,
  );
}

Future<List<CommitRecord>> _readCommitCsv(File file) async {
  final rows = _parseCsv(await file.readAsString());
  if (rows.isEmpty) {
    return [];
  }

  final header = rows.first;
  final commits = <CommitRecord>[];
  for (final row in rows.skip(1)) {
    if (row.every((cell) => cell.isEmpty)) {
      continue;
    }
    final mapped = <String, String>{};
    for (var i = 0; i < header.length; i += 1) {
      mapped[header[i]] = i < row.length ? row[i] : '';
    }
    commits.add(CommitRecord.fromCsvRow(mapped));
  }
  return commits;
}

Color _actionColor(String action) {
  switch (action) {
    case 'A':
      return Colors.green;
    case 'M':
      return Colors.blue;
    case 'D':
      return Colors.red;
    case 'R':
      return Colors.orange;
    default:
      return Colors.blueGrey;
  }
}

String _shortCommitDate(String date) {
  if (date.length >= 10) {
    return date.substring(0, 10);
  }
  return date;
}

String _backendStatusSummary(String status) {
  if (status.contains('已連線')) {
    return '已連線';
  }
  if (status.contains('正在')) {
    return '檢查中';
  }
  if (status.contains('Connection refused') ||
      status.contains('拒絕') ||
      status.contains('errno = 1225') ||
      status.contains('無法連線')) {
    return '未連線';
  }
  if (status.contains('失敗') ||
      status.contains('無法') ||
      status.contains('中斷') ||
      status.contains('異常')) {
    return '異常';
  }
  return '未確認';
}

class _BackendStatusStyle {
  const _BackendStatusStyle({
    required this.color,
    required this.icon,
  });

  final Color color;
  final IconData icon;
}

_BackendStatusStyle _backendStatusStyle(String summary) {
  switch (summary) {
    case '已連線':
      return const _BackendStatusStyle(
        color: Colors.green,
        icon: Icons.check_circle_rounded,
      );
    case '檢查中':
      return const _BackendStatusStyle(
        color: Colors.blue,
        icon: Icons.sync_rounded,
      );
    case '異常':
      return const _BackendStatusStyle(
        color: Colors.red,
        icon: Icons.error_rounded,
      );
    case '未連線':
      return const _BackendStatusStyle(
        color: Colors.orange,
        icon: Icons.link_off_rounded,
      );
    default:
      return const _BackendStatusStyle(
        color: Colors.grey,
        icon: Icons.help_rounded,
      );
  }
}

class RevisionDiffResult {
  const RevisionDiffResult({
    required this.diff,
    required this.repoName,
    required this.revision,
    required this.path,
    required this.cacheFile,
    required this.cached,
  });

  final String diff;
  final String repoName;
  final int revision;
  final String path;
  final String cacheFile;
  final bool cached;
}

Future<RevisionDiffResult> _loadRevisionDiff({
  required AppSettings settings,
  required SvnRepository repository,
  required int revision,
  required String path,
  bool refresh = false,
}) async {
  final cacheDir = Directory(_joinPath(
    _joinPath(settings.notesRootPath, '.diff_cache'),
    repository.name,
  ));
  if (!await cacheDir.exists()) {
    await cacheDir.create(recursive: true);
  }

  final cacheFile = File(_joinPath(cacheDir.path, 'r${revision}_$path.txt'));
  if (!refresh && await cacheFile.exists()) {
    return RevisionDiffResult(
      diff: await cacheFile.readAsString(),
      repoName: repository.name,
      revision: revision,
      path: path,
      cacheFile: cacheFile.path,
      cached: true,
    );
  }

  final baseUrl = settings.ollamaBaseUrl.replaceAll(RegExp(r'/+$'), '');
  final encodedPath = base64Encode(utf8.encode(path));
  final url = Uri.parse('$baseUrl/api/diff/$encodedPath');

  final response = await HttpClient()
      .getUrl(url)
      .then((request) {
    if (settings.ollamaApiKey.isNotEmpty) {
      request.headers.set('Authorization', 'Bearer ${settings.ollamaApiKey}');
    }
    return request.close();
  });

  final body = await response.transform(utf8.decoder).join();
  if (response.statusCode != 200) {
    throw Exception('Failed to load diff: HTTP ${response.statusCode}\n$body');
  }

  await cacheFile.writeAsString(body);
  return RevisionDiffResult(
    diff: body,
    repoName: repository.name,
    revision: revision,
    path: path,
    cacheFile: cacheFile.path,
    cached: false,
  );
}

List<_DiffFile> _parseUnifiedDiff(String diff) {
  final files = <_DiffFile>[];
  var currentFile = _DiffFile.empty();
  var inHeader = false;
  var inDiff = false;

  for (final line in diff.split('\n')) {
    if (line.startsWith('--- ') && line.length > 4) {
      if (currentFile.lines.isNotEmpty) {
        files.add(currentFile);
      }
      currentFile = _DiffFile(name: line.substring(4).trim());
      inHeader = true;
      inDiff = false;
      continue;
    }
    if (line.startsWith('+++ ')) {
      inHeader = false;
      inDiff = true;
      currentFile.lines.add(line);
      continue;
    }
    if (line.startsWith('@@')) {
      inHeader = false;
      inDiff = true;
      currentFile.lines.add(line);
      continue;
    }
    if (inHeader || line.startsWith('Index:') || line.startsWith('diff ')) {
      continue;
    }
    if (inDiff) {
      currentFile.lines.add(line);
    }
  }

  if (currentFile.lines.isNotEmpty) {
    files.add(currentFile);
  }
  return files;
}

class _DiffFile {
  _DiffFile({required this.name}) : lines = [];

  factory _DiffFile.empty() => _DiffFile(name: '');

  final String name;
  final List<String> lines;
}
