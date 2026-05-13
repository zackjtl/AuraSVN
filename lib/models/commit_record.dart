import 'dart:convert';

import 'package:aura_svn/utils/helpers.dart';

class ChangedPath {
  const ChangedPath({
    required this.action,
    required this.path,
    this.copyFromPath,
    this.copyFromRev,
  });

  factory ChangedPath.fromJson(Map<String, dynamic> json) {
    return ChangedPath(
      action: json['action']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      copyFromPath: json['copyfrom_path']?.toString(),
      copyFromRev: asInt(json['copyfrom_rev']),
    );
  }

  final String action;
  final String path;
  final String? copyFromPath;
  final int? copyFromRev;
}

class CommitRecord {
  const CommitRecord({
    required this.revision,
    required this.author,
    required this.date,
    required this.ticketId,
    required this.message,
    required this.changedPaths,
  });

  factory CommitRecord.fromCsvRow(Map<String, String> row) {
    final changedPathJson = row['changed_paths'] ?? '[]';
    final decoded = jsonDecode(changedPathJson);
    final paths = decoded is List
        ? decoded
            .whereType<Map>()
            .map(
                (item) => ChangedPath.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <ChangedPath>[];

    return CommitRecord(
      revision: int.tryParse(row['revision'] ?? '') ?? 0,
      author: row['author'] ?? '',
      date: row['date'] ?? '',
      ticketId: row['ticket_id'] ?? '',
      message: row['message'] ?? '',
      changedPaths: paths,
    );
  }

  final int revision;
  final String author;
  final String date;
  final String ticketId;
  final String message;
  final List<ChangedPath> changedPaths;
}
