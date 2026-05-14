import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aura_svn/models/project_report_log_entry.dart';
import 'package:aura_svn/models/svn_repository.dart';
import 'package:aura_svn/utils/helpers.dart';
import 'package:aura_svn/utils/path_utils.dart';

const svnTrustArg =
    '--trust-server-cert-failures=unknown-ca,cn-mismatch,expired,not-yet-valid,other';

class AppSettings {
  const AppSettings({
    required this.notesRootPath,
    required this.backendBaseUrl,
    required this.ollamaBaseUrl,
    required this.ollamaModel,
    required this.ollamaApiKey,
    required this.svnCommand,
    required this.svnCommandParameters,
    required this.pythonCommand,
    required this.languageCode,
    required this.appearanceThemeCode,
    required this.repositories,
    this.branchMapOrientation = kBranchMapOrientationTopBottom,
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      notesRootPath: json['notes_root_path']?.toString() ?? '',
      backendBaseUrl:
          json['backend_base_url']?.toString() ?? 'http://127.0.0.1:8765',
      ollamaBaseUrl:
          json['ollama_base_url']?.toString() ?? 'http://localhost:11434',
      ollamaModel: json['ollama_model']?.toString() ?? 'qwen3-coder-next',
      ollamaApiKey: json['ollama_api_key']?.toString() ?? '',
      svnCommand: json['svn_command']?.toString() ?? defaultSvnCommand(),
      svnCommandParameters:
          json['svn_command_parameters']?.toString() ?? defaultSvnParameters(),
      pythonCommand:
          json['python_command']?.toString() ?? defaultPythonCommand(),
      languageCode: _normalizeLanguageCode(json['language_code']?.toString()),
      appearanceThemeCode:
          _normalizeAppearanceThemeCode(json['appearance_theme']?.toString()),
      repositories: _repositoryProfilesFromJson(json['repository_profiles']),
      branchMapOrientation:
          _normalizeBranchMapOrientation(json['branch_map_orientation']),
    );
  }

  factory AppSettings.defaults(Directory projectRoot) {
    return AppSettings(
      notesRootPath: joinPath(projectRoot.path, 'branch_notes'),
      backendBaseUrl: 'http://127.0.0.1:8765',
      ollamaBaseUrl: 'http://localhost:11434',
      ollamaModel: 'qwen3-coder-next',
      ollamaApiKey: '',
      svnCommand: defaultSvnCommand(),
      svnCommandParameters: defaultSvnParameters(),
      pythonCommand: defaultPythonCommand(),
      languageCode: 'zh_TW',
      appearanceThemeCode: 'night',
      repositories: defaultRepositories,
    );
  }

  final String notesRootPath;
  final String backendBaseUrl;
  final String ollamaBaseUrl;
  final String ollamaModel;
  final String ollamaApiKey;
  final String svnCommand;
  final String svnCommandParameters;
  final String pythonCommand;
  final String languageCode;
  final String appearanceThemeCode;
  final List<SvnRepository> repositories;

  /// 與 graphview `BuchheimWalkerConfiguration` 一致：`1` = 由上到下，`3` = 由左到右。
  final int branchMapOrientation;

  AppSettings copyWith({
    String? notesRootPath,
    String? backendBaseUrl,
    String? ollamaBaseUrl,
    String? ollamaModel,
    String? ollamaApiKey,
    String? svnCommand,
    String? svnCommandParameters,
    String? pythonCommand,
    String? languageCode,
    String? appearanceThemeCode,
    List<SvnRepository>? repositories,
    int? branchMapOrientation,
  }) {
    return AppSettings(
      notesRootPath: notesRootPath ?? this.notesRootPath,
      backendBaseUrl: backendBaseUrl ?? this.backendBaseUrl,
      ollamaBaseUrl: ollamaBaseUrl ?? this.ollamaBaseUrl,
      ollamaModel: ollamaModel ?? this.ollamaModel,
      ollamaApiKey: ollamaApiKey ?? this.ollamaApiKey,
      svnCommand: svnCommand ?? this.svnCommand,
      svnCommandParameters:
          svnCommandParameters ?? this.svnCommandParameters,
      pythonCommand: pythonCommand ?? this.pythonCommand,
      languageCode: languageCode ?? this.languageCode,
      appearanceThemeCode:
          appearanceThemeCode ?? this.appearanceThemeCode,
      repositories: repositories ?? this.repositories,
      branchMapOrientation:
          branchMapOrientation ?? this.branchMapOrientation,
    );
  }

  Map<String, dynamic> toJson() => {
        'notes_root_path': notesRootPath,
        'backend_base_url': backendBaseUrl,
        'ollama_base_url': ollamaBaseUrl,
        'ollama_model': ollamaModel,
        'ollama_api_key': ollamaApiKey,
        'svn_command': svnCommand,
        'svn_command_parameters': svnCommandParameters,
        'python_command': pythonCommand,
        'language_code': languageCode,
        'appearance_theme': appearanceThemeCode,
        'repository_profiles':
            repositories.map((repository) => repository.toJson()).toList(),
        'branch_map_orientation': branchMapOrientation,
      };
}

/// graphview `ORIENTATION_TOP_BOTTOM`
const int kBranchMapOrientationTopBottom = 1;

/// graphview `ORIENTATION_LEFT_RIGHT`
const int kBranchMapOrientationLeftRight = 3;

int _normalizeBranchMapOrientation(Object? value) {
  final v = switch (value) {
    int i => i,
    num n => n.toInt(),
    String s => int.tryParse(s.trim()) ?? kBranchMapOrientationTopBottom,
    _ => kBranchMapOrientationTopBottom,
  };
  if (v == kBranchMapOrientationLeftRight) {
    return kBranchMapOrientationLeftRight;
  }
  return kBranchMapOrientationTopBottom;
}

List<SvnRepository> _repositoryProfilesFromJson(Object? value) {
  if (value is! List) {
    return defaultRepositories;
  }
  final repositories = value
      .whereType<Map>()
      .map((item) => SvnRepository.fromJson(Map<String, dynamic>.from(item)))
      .where((repository) =>
          repository.name.trim().isNotEmpty && repository.url.trim().isNotEmpty)
      .toList();
  return repositories.isEmpty ? defaultRepositories : repositories;
}

String _normalizeLanguageCode(String? value) {
  return value == 'en' ? 'en' : 'zh_TW';
}

String _normalizeAppearanceThemeCode(String? value) {
  return value == 'day' ? 'day' : 'night';
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

Future<AppSettings> loadAppSettings(Directory projectRoot) async {
  final file =
      File(joinPath(settingsDir(projectRoot).path, 'app_settings.json'));
  if (!await file.exists()) {
    return AppSettings.defaults(projectRoot);
  }

  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, dynamic>) {
    return AppSettings.defaults(projectRoot);
  }
  final settings = AppSettings.fromJson(decoded);
  if (settings.notesRootPath.isEmpty) {
    return AppSettings.defaults(projectRoot);
  }
  return settings;
}

Future<void> saveAppSettings(
    Directory projectRoot, AppSettings settings) async {
  if (settings.notesRootPath.trim().isEmpty) {
    throw Exception('Markdown 筆記根目錄不可為空。');
  }
  if (settings.backendBaseUrl.trim().isEmpty) {
    throw Exception('本地後端 URL 不可為空。');
  }
  if (settings.svnCommand.trim().isEmpty) {
    throw Exception('SVN Command 不可為空。');
  }
  if (settings.pythonCommand.trim().isEmpty) {
    throw Exception('Python Command 不可為空。');
  }
  if (settings.repositories.isEmpty) {
    throw Exception('至少需要一個 Repository Profile。');
  }
  final seenTitles = <String>{};
  for (final repository in settings.repositories) {
    final title = repository.name.trim();
    if (title.isEmpty) {
      throw Exception('Repository Profile Title 不可為空。');
    }
    if (repository.url.trim().isEmpty) {
      throw Exception('Repository Profile SVN Base URL 不可為空：$title');
    }
    if (!seenTitles.add(title)) {
      throw Exception('Repository Profile Title 不可重複：$title');
    }
  }

  final notesRoot = Directory(settings.notesRootPath);
  if (!await notesRoot.exists()) {
    await notesRoot.create(recursive: true);
  }

  final dir = settingsDir(projectRoot);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final file = File(joinPath(dir.path, 'app_settings.json'));
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(settings.toJson()),
    encoding: utf8,
  );
}

Future<BranchNoteDocument> loadBranchNote({
  required AppSettings settings,
  required SvnRepository repository,
  required String branchPath,
}) async {
  final decoded = await backendPost(settings, '/api/notes/read', {
    'notes_root': settings.notesRootPath,
    'repo': repository.name,
    'branch_path': branchPath,
  });
  return BranchNoteDocument(
    repoName: decoded['repo']?.toString() ?? repository.name,
    branchPath: decoded['branch_path']?.toString() ?? branchPath,
    noteFile: decoded['note_file']?.toString() ?? '',
    content: decoded['content']?.toString() ?? '',
    updatedAt: parseDateTime(decoded['updated_at']),
  );
}

Future<BranchNoteDocument> saveBranchNote({
  required AppSettings settings,
  required SvnRepository repository,
  required String branchPath,
  required String content,
}) async {
  if (settings.notesRootPath.trim().isEmpty) {
    throw Exception('請先到設定頁指定 Markdown 筆記根目錄。');
  }

  final decoded = await backendPost(settings, '/api/notes/write', {
    'notes_root': settings.notesRootPath,
    'repo': repository.name,
    'branch_path': branchPath,
    'content': content,
  });
  return BranchNoteDocument(
    repoName: decoded['repo']?.toString() ?? repository.name,
    branchPath: decoded['branch_path']?.toString() ?? branchPath,
    noteFile: decoded['note_file']?.toString() ?? '',
    content: decoded['content']?.toString() ?? content,
    updatedAt: parseDateTime(decoded['updated_at']) ?? DateTime.now(),
  );
}

Future<ProjectReportResult> generateProjectReportStream({
  required AppSettings settings,
  required SvnRepository repository,
  required String reportTitle,
  required String userPrompt,
  required void Function(ProjectReportLogEntry entry) onLog,
}) async {
  if (settings.notesRootPath.trim().isEmpty) {
    throw Exception('請先到設定頁指定 Markdown 筆記根目錄。');
  }

  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final base = settings.backendBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final payload = {
      'repo': repository.name,
      'repo_svn_url': repository.url,
      'notes_root': settings.notesRootPath,
      'ollama_base_url': settings.ollamaBaseUrl,
      'model': settings.ollamaModel,
      'ollama_api_key': settings.ollamaApiKey,
      'report_title': reportTitle,
      'user_prompt': userPrompt,
    };
    final bodyBytes = utf8.encode(jsonEncode(payload));
    final request =
        await client.postUrl(Uri.parse('$base/api/reports/project_stream'));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.connectionHeader, 'close');
    request.contentLength = bodyBytes.length;
    request.add(bodyBytes);

    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.transform(utf8.decoder).join();
      throw Exception(body.isEmpty
          ? 'Backend HTTP ${response.statusCode}'
          : 'Backend HTTP ${response.statusCode}: $body');
    }

    ProjectReportResult? result;
    await for (final line
        in response.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.trim().isEmpty) {
        continue;
      }
      final decoded = jsonDecode(line);
      if (decoded is! Map<String, dynamic>) {
        onLog(ProjectReportLogEntry(
          level: 'warn',
          message: '收到非物件格式的後端事件：$line',
          time: DateTime.now(),
        ));
        continue;
      }

      final type = decoded['type']?.toString() ?? 'log';
      if (type == 'log') {
        onLog(ProjectReportLogEntry.fromJson(decoded));
      } else if (type == 'error') {
        final entry = ProjectReportLogEntry.fromJson(decoded);
        onLog(entry);
        throw Exception(entry.message);
      } else if (type == 'result') {
        result = ProjectReportResult.fromJson(
          decoded,
          fallbackRepoName: repository.name,
          fallbackModel: settings.ollamaModel,
        );
      } else {
        onLog(ProjectReportLogEntry(
          level: 'warn',
          message: '收到未知後端事件 type=$type',
          time: DateTime.now(),
        ));
      }
    }

    if (result == null) {
      throw Exception('後端串流已結束，但沒有回傳報告結果。');
    }
    return result;
  } on SocketException catch (error) {
    throw Exception(
      '無法連線到本地後端：${settings.backendBaseUrl}。原始錯誤：${error.message}',
    );
  } on HttpException catch (error) {
    throw Exception(
      '後端連線中斷：${settings.backendBaseUrl}。原始錯誤：${error.message}',
    );
  } finally {
    client.close(force: true);
  }
}

Future<List<ProjectReportResult>> loadProjectReportHistory({
  required AppSettings settings,
  required SvnRepository repository,
}) async {
  if (settings.notesRootPath.trim().isEmpty) {
    throw Exception('請先到設定頁指定 Markdown 筆記根目錄。');
  }

  final decoded = await backendPost(settings, '/api/reports/history', {
    'repo': repository.name,
    'notes_root': settings.notesRootPath,
  });
  final reports = decoded['reports'];
  if (reports is! List) {
    return [];
  }
  return reports
      .whereType<Map>()
      .map(
        (item) => ProjectReportResult.fromJson(
          Map<String, dynamic>.from(item),
          fallbackRepoName: repository.name,
          fallbackModel: settings.ollamaModel,
        ),
      )
      .toList();
}

Future<RevisionDiffResult> loadRevisionDiff({
  required AppSettings settings,
  required SvnRepository repository,
  required int revision,
  String? path,
  bool refresh = false,
}) async {
  final decoded = await backendPost(
    settings,
    '/api/revisions/diff',
    {
      'repo': repository.name,
      'revision': revision,
      if (path != null && path.trim().isNotEmpty) 'path': path.trim(),
      'refresh': refresh,
    },
    timeout: const Duration(seconds: 120),
  );
  return RevisionDiffResult(
    repoName: decoded['repo']?.toString() ?? repository.name,
    revision: asInt(decoded['revision']) ?? revision,
    path: decoded['path']?.toString() ?? path ?? '',
    diff: decoded['diff']?.toString() ?? '',
    cacheFile: decoded['cache_file']?.toString() ?? '',
    cached: decoded['cached'] == true,
  );
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
      createdAt: parseDateTime(json['created_at']),
    );
  }

  final String id;
  final String repoName;
  final String model;
  final String title;
  final String userPrompt;
  final String report;
  final String reportFile;
  final DateTime? createdAt;
}

class RevisionDiffResult {
  const RevisionDiffResult({
    required this.repoName,
    required this.revision,
    required this.path,
    required this.diff,
    required this.cacheFile,
    required this.cached,
  });

  final String repoName;
  final int revision;
  final String path;
  final String diff;
  final String cacheFile;
  final bool cached;
}

Directory settingsDir(Directory projectRoot) {
  return Directory(joinPath(projectRoot.path, '.runtime_configs'));
}

Future<Map<String, dynamic>> backendPost(
  AppSettings settings,
  String path,
  Map<String, dynamic> payload, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final client = HttpClient();
  try {
    final base = settings.backendBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final bodyBytes = utf8.encode(jsonEncode(payload));
    final request = await client.postUrl(Uri.parse('$base$path'));
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.connectionHeader, 'close');
    request.contentLength = bodyBytes.length;
    request.add(bodyBytes);
    final response = await request.close().timeout(timeout);
    final body = await response.transform(utf8.decoder).join();
    final decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(decoded is Map && decoded['error'] != null
          ? decoded['error']
          : 'Backend HTTP ${response.statusCode}');
    }
    if (decoded is Map<String, dynamic>) {
      if (decoded['error'] != null) {
        throw Exception(decoded['error']);
      }
      return decoded;
    }
    throw Exception('Backend response is not an object.');
  } on SocketException catch (error) {
    throw Exception(
      '無法連線到本地後端：${settings.backendBaseUrl}。請到設定頁按「啟動本地後端」或「檢查狀態」。原始錯誤：${error.message}',
    );
  } on HttpException catch (error) {
    throw Exception(
      '後端連線中斷：${settings.backendBaseUrl}。請確認後端仍在執行，或到設定頁重新啟動。原始錯誤：${error.message}',
    );
  } finally {
    client.close(force: true);
  }
}

String defaultSvnCommand() {
  if (Platform.isWindows) {
    return r'C:\Program Files\TortoiseSVN\bin\svn.exe';
  }
  return 'svn';
}

String defaultSvnParameters() {
  return '--non-interactive $svnTrustArg';
}

String defaultPythonCommand() {
  return Platform.isWindows ? 'py -3.14' : 'python3';
}
