import 'dart:convert';

class SvnRepository {
  const SvnRepository(this.name, this.url, {this.subtitle = ''});

  factory SvnRepository.fromJson(Map<String, dynamic> json) {
    return SvnRepository(
      json['title']?.toString().trim() ?? '',
      json['svn_base_url']?.toString().trim() ?? '',
      subtitle: json['sub_title']?.toString().trim() ?? '',
    );
  }

  final String name;
  final String url;
  final String subtitle;

  Map<String, dynamic> toJson() => {
        'title': name,
        'sub_title': subtitle,
        'svn_base_url': url,
      };
}

SvnRepository? _matchRepository(
  List<SvnRepository> repositories,
  SvnRepository selected,
) {
  for (final repository in repositories) {
    if (repository.name == selected.name) {
      return repository;
    }
  }
  return null;
}

class AppData {
  const AppData({
    required this.topology,
    required this.commits,
    required this.shardNames,
  });

  factory AppData.empty() => const AppData(
        topology: {},
        commits: [],
        shardNames: [],
      );

  final Map<String, BranchNode> topology;
  final List<CommitRecord> commits;
  final List<String> shardNames;

  bool get isEmpty => topology.isEmpty && commits.isEmpty;

  CommitRecord? get latestCommit => commits.isEmpty ? null : commits.first;
}

class BranchNode {
  const BranchNode({
    required this.children,
    this.kind,
    this.originRev,
    this.parent,
    this.parentRev,
    this.copyFromPath,
    this.copyFromRev,
  });

  factory BranchNode.fromJson(Map<String, dynamic> json) {
    return BranchNode(
      children: (json['children'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      kind: json['kind']?.toString(),
      originRev: _asInt(json['origin_rev']),
      parent: json['parent']?.toString(),
      parentRev: _asInt(json['parent_rev']),
      copyFromPath: json['copyfrom_path']?.toString(),
      copyFromRev: _asInt(json['copyfrom_rev']),
    );
  }

  final List<String> children;
  final String? kind;
  final int? originRev;
  final String? parent;
  final int? parentRev;
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
      copyFromRev: _asInt(json['copyfrom_rev']),
    );
  }

  final String action;
  final String path;
  final String? copyFromPath;
  final int? copyFromRev;
}

class BranchNoteDocument {
  const BranchNoteDocument({
    required this.repoName,
    required this.branchPath,
    required this.noteFile,
    required this.content,
    this.updatedAt,
  });

  final String repoName;
  final String branchPath;
  final String noteFile;
  final String content;
  final DateTime? updatedAt;
}

class ProjectReportResult {
  const ProjectReportResult({
    required this.id,
    required this.repoName,
    required this.model,
    required this.title,
    required this.userPrompt,
    required this.report,
    required this.reportFile,
    required this.createdAt,
  });

  factory ProjectReportResult.fromJson(
    Map<String, dynamic> json, {
    required String fallbackRepoName,
    required String fallbackModel,
  }) {
    return ProjectReportResult(
      id: json['id']?.toString() ?? '',
      repoName: json['repo']?.toString() ?? fallbackRepoName,
      model: json['model']?.toString() ?? fallbackModel,
      title: json['title']?.toString() ?? '',
      userPrompt: (json['user_prompt'] ?? json['prompt'])?.toString() ?? '',
      report: json['report']?.toString() ?? '',
      reportFile: json['report_file']?.toString() ?? '',
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  final String id;
  final String repoName;
  final String model;
  final String title;
  final String userPrompt;
  final String report;
  final String reportFile;
  final   DateTime? createdAt;
}

class ProjectReportLogEntry {
  const ProjectReportLogEntry({
    required this.level,
    required this.message,
    required this.time,
  });

  factory ProjectReportLogEntry.fromJson(Map<String, dynamic> json) {
    return ProjectReportLogEntry(
      level: json['level']?.toString() ?? 'info',
      message: json['message']?.toString() ?? '',
      time: _parseDateTime(json['time']) ?? DateTime.now(),
    );
  }

  final String level;
  final String message;
  final DateTime time;
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

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

DateTime? _parseDateTime(Object? value) {
  final text = value?.toString() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
}
