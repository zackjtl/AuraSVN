import 'dart:convert';
import 'dart:io';

import 'package:aura_svn/models/app_data.dart';
import 'package:aura_svn/models/branch_node.dart';
import 'package:aura_svn/models/commit_record.dart';
import 'package:aura_svn/models/svn_repository.dart';
import 'package:aura_svn/utils/csv_parser.dart';
import 'package:aura_svn/utils/path_utils.dart';

Future<Directory> findProjectRoot() async {
  var directory = Directory.current.absolute;
  for (var i = 0; i < 8; i += 1) {
    final marker = File(joinPath(directory.path, 'scripts', 'svn_to_ai_loader.py'));
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

Future<AppData> readOutput(
  Directory root,
  SvnRepository repository,
) async {
  final outputDir = Directory(
    joinPath(joinPath(root.path, 'svn_ai_output'), repository.name),
  );
  if (!await outputDir.exists()) {
    return AppData.empty();
  }

  final topology = <String, BranchNode>{};
  final topologyFile = File(joinPath(outputDir.path, 'branch_topology.json'));
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
    final name = fileName(entity.path);
    if (!shardPattern.hasMatch(name)) {
      continue;
    }
    shardNames.add(name);
    commits.addAll(await readCommitCsv(entity));
  }

  commits.sort((a, b) => b.revision.compareTo(a.revision));
  shardNames.sort();

  return AppData(
    topology: topology,
    commits: commits,
    shardNames: shardNames,
  );
}

Future<List<CommitRecord>> readCommitCsv(File file) async {
  final rows = parseCsv(await file.readAsString());
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
