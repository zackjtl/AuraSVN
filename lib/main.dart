import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aura_svn/app_theme.dart';
import 'package:aura_svn/branch_map_view.dart';
import 'package:aura_svn/data/data_loader.dart';
import 'package:aura_svn/language_scope.dart';
import 'package:aura_svn/models/app_data.dart';
import 'package:aura_svn/models/svn_repository.dart';
import 'package:aura_svn/notes_store.dart';
import 'package:aura_svn/project_report_view.dart';
import 'package:aura_svn/settings_view.dart';
import 'package:aura_svn/utils/command_line.dart';
import 'package:aura_svn/utils/path_utils.dart';
import 'package:aura_svn/widgets/commit_widgets.dart';
import 'package:aura_svn/widgets/dashboard_widgets.dart';
import 'package:aura_svn/widgets/data_panel_widgets.dart';
import 'package:aura_svn/widgets/page_header_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const SvnBranchViewerApp());
}

class SvnBranchViewerApp extends StatelessWidget {
  const SvnBranchViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appearanceThemeNotifier,
      builder: (context, appearanceThemeCode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Aura SVN',
          theme: buildAuraThemeData(appearanceThemeCode),
          home: const DashboardPage(),
        );
      },
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  SvnRepository _selectedRepository = defaultRepositories.first;
  List<SvnRepository> _repositoryProfiles = List.of(defaultRepositories);
  AppData _data = AppData.empty();
  Directory? _projectRoot;
  bool _isInitializing = true;
  bool _isRefreshing = false;
  bool _showVisualMap = false;
  bool _showSettings = false;
  bool _showRepositoryProfiles = false;
  bool _showAiAnalysis = false;
  bool _showAiHistory = false;
  bool _showAiChat = false;
  bool _controlPanelCollapsed = false;
  bool _outputConsoleExpanded = false;
  String? _branchCommitsPath;
  int? _commitListExpandedRevision;
  /// false = Commit 列表，true = Markdown 筆記（分支詳情頁頂部切換）
  bool _branchCommitsMarkdownTab = false;
  String? _error;
  String _lastUpdateStatus = '尚未執行更新';
  String _languageCode = 'zh_TW';
  String _appearanceThemeCode = 'night';
  int _repoUpdateCheckToken = 0;
  AppSettings _settings = const AppSettings(
    notesRootPath: '',
    backendBaseUrl: 'http://127.0.0.1:8765',
    ollamaBaseUrl: 'http://localhost:11434',
    ollamaModel: 'qwen3-coder-next',
    ollamaApiKey: '',
    svnCommand: '',
    svnCommandParameters: '',
    pythonCommand: '',
    languageCode: 'zh_TW',
    appearanceThemeCode: 'night',
    repositories: defaultRepositories,
    branchMapOrientation: kBranchMapOrientationTopBottom,
  );
  Process? _backendProcess;
  bool _isBackendBusy = false;
  bool _ollamaTestBusy = false;
  String _backendStatus = '尚未檢查後端狀態';
  final _backendOutputBuffer = <String>[];
  final _logs = <String>[];
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _notesRootController = TextEditingController();
  final _backendUrlController = TextEditingController();
  final _ollamaUrlController = TextEditingController();
  final _ollamaModelController = TextEditingController();
  final _ollamaApiKeyController = TextEditingController();
  final _svnCommandController = TextEditingController();
  final _svnParametersController = TextEditingController();
  final _pythonController = TextEditingController();
  final _aiReportTitleController = TextEditingController();
  final _aiPromptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _notesRootController.dispose();
    _backendUrlController.dispose();
    _ollamaUrlController.dispose();
    _ollamaModelController.dispose();
    _ollamaApiKeyController.dispose();
    _svnCommandController.dispose();
    _svnParametersController.dispose();
    _pythonController.dispose();
    _aiReportTitleController.dispose();
    _aiPromptController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final root = await findProjectRoot();
      final settings = await loadAppSettings(root);
      final repositories = settings.repositories;
      final selectedRepository = repositories.first;
      final data = await readOutput(root, selectedRepository);
      if (!mounted) {
        return;
      }
      setState(() {
        _projectRoot = root;
        _settings = settings;
        _repositoryProfiles = repositories;
        _selectedRepository = selectedRepository;
        _languageCode = settings.languageCode;
        _appearanceThemeCode = settings.appearanceThemeCode;
        appearanceThemeNotifier.value = settings.appearanceThemeCode;
        _notesRootController.text = settings.notesRootPath;
        _backendUrlController.text = settings.backendBaseUrl;
        _ollamaUrlController.text = settings.ollamaBaseUrl;
        _ollamaModelController.text = settings.ollamaModel;
        _ollamaApiKeyController.text = settings.ollamaApiKey;
        _svnCommandController.text = settings.svnCommand;
        _svnParametersController.text = settings.svnCommandParameters;
        _pythonController.text = settings.pythonCommand;
        _data = data;
        _isInitializing = false;
        _lastUpdateStatus = data.isEmpty ? '尚無本地資料' : '已載入本地資料';
      });
      Future<void>.microtask(_connectExistingBackendOnStartup);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isInitializing = false;
      });
    }
  }

  Future<void> _connectExistingBackendOnStartup() async {
    for (var attempt = 0; attempt < 3; attempt += 1) {
      await _checkBackendStatus();
      if (!mounted || _backendStatus.contains('已連線')) {
        return;
      }
      await Future<void>.delayed(Duration(milliseconds: 450 * (attempt + 1)));
    }

    if (!mounted || _backendStatus.contains('已連線')) {
      return;
    }

    final backendUrl = _backendUrlController.text.trim().isEmpty
        ? _settings.backendBaseUrl
        : _backendUrlController.text.trim();
    if (!_isLocalBackendUrl(backendUrl)) {
      return;
    }

    setState(() {
      _backendStatus = '後端未連線，正在背景自動修復：關閉舊 process 並啟動本地後端...';
    });
    await _stopBackendProcesses();
    if (!mounted || _backendStatus.contains('已連線')) {
      return;
    }
    await _startBackend();
  }

  bool _isLocalBackendUrl(String backendUrl) {
    if (backendUrl.trim().isEmpty) {
      return false;
    }
    final uri = Uri.parse(backendUrl);
    final host = uri.host.isEmpty ? '127.0.0.1' : uri.host;
    return host == '127.0.0.1' || host == 'localhost' || host == '::1';
  }

  Future<void> _checkBackendStatus() async {
    final backendUrl = _backendUrlController.text.trim().isEmpty
        ? _settings.backendBaseUrl
        : _backendUrlController.text.trim();
    if (backendUrl.isEmpty) {
      setState(() {
        _backendStatus = '請先設定本地後端 URL。';
      });
      return;
    }

    setState(() {
      _isBackendBusy = true;
      _backendStatus = '正在檢查後端連線...';
    });

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final base = backendUrl.replaceAll(RegExp(r'/+$'), '');
      final request = await client.getUrl(Uri.parse('$base/api/health'));
      final response =
          await request.close().timeout(const Duration(seconds: 5));
      final body = await response.transform(utf8.decoder).join();
      final decoded = body.isEmpty ? <String, dynamic>{} : jsonDecode(body);
      if (!mounted) {
        return;
      }
      setState(() {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final keyLoaded =
              decoded is Map && decoded['ollama_api_key_loaded'] == true;
          _backendStatus =
              '後端已連線 (${response.statusCode})，Ollama API key（後端設定檔 app_settings.json）：${keyLoaded ? '已載入' : '未載入'}';
        } else {
          _backendStatus = '後端回應異常：HTTP ${response.statusCode}';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _backendStatus = _formatBackendConnectionError(error);
      });
    } finally {
      client.close(force: true);
      if (mounted) {
        setState(() {
          _isBackendBusy = false;
        });
      }
    }
  }

  Future<void> _testOllamaSettings() async {
    final messenger = ScaffoldMessenger.of(context);
    final backendUrl = _backendUrlController.text.trim().isEmpty
        ? _settings.backendBaseUrl
        : _backendUrlController.text.trim();
    final ollamaUrl = _ollamaUrlController.text.trim();
    final model = _ollamaModelController.text.trim();

    if (backendUrl.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            t(context, '請先填寫本地後端 URL。', 'Please enter the local backend URL first.'),
          ),
        ),
      );
      return;
    }
    if (ollamaUrl.isEmpty || model.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            t(
              context,
              '請填寫 Ollama Base URL 與 Model。',
              'Please enter Ollama Base URL and Model.',
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _ollamaTestBusy = true;
    });
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final base = backendUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$base/api/ollama/test');
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.connectionHeader, 'close');
      final bodyBytes = utf8.encode(
        jsonEncode({
          'ollama_base_url': ollamaUrl,
          'model': model,
          'api_key': _ollamaApiKeyController.text.trim(),
        }),
      );
      request.contentLength = bodyBytes.length;
      request.add(bodyBytes);
      final response =
          await request.close().timeout(const Duration(seconds: 90));
      final responseBody = await response.transform(utf8.decoder).join();
      if (!mounted) {
        return;
      }
      Map<String, dynamic>? decoded;
      try {
        final obj = jsonDecode(responseBody);
        if (obj is Map<String, dynamic>) {
          decoded = obj;
        }
      } catch (_) {}
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded != null &&
          decoded['ok'] == true) {
        final preview = (decoded['reply_preview'] ?? '').toString();
        final truncated = preview.length > 120
            ? '${preview.substring(0, 120)}…'
            : preview;
        final usedUrl = (decoded['ollama_chat_url'] ?? '').toString();
        var msg = truncated.isEmpty
            ? t(context, 'Ollama 測試成功。', 'Ollama test succeeded.')
            : t(
                context,
                'Ollama 測試成功：$truncated',
                'Ollama test succeeded: $truncated',
              );
        if (usedUrl.isNotEmpty) {
          msg = '$msg\n→ $usedUrl';
        }
        messenger.showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 8)),
        );
      } else {
        final err = decoded?['error']?.toString() ??
            (responseBody.isEmpty
                ? 'HTTP ${response.statusCode}'
                : responseBody);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              t(context, 'Ollama 測試失敗：$err', 'Ollama test failed: $err'),
            ),
            backgroundColor: Colors.red.shade800,
            duration: const Duration(seconds: 12),
          ),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            t(
              context,
              'Ollama 測試失敗：${_formatBackendConnectionError(error)}',
              'Ollama test failed: ${_formatBackendConnectionError(error)}',
            ),
          ),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 10),
        ),
      );
    } finally {
      client.close(force: true);
      if (mounted) {
        setState(() {
          _ollamaTestBusy = false;
        });
      }
    }
  }

  Future<void> _startBackend() async {
    final root = _projectRoot;
    if (root == null) {
      return;
    }

    final backendUrl = _backendUrlController.text.trim().isEmpty
        ? _settings.backendBaseUrl
        : _backendUrlController.text.trim();
    final uri = Uri.parse(backendUrl);
    final host = uri.host.isEmpty ? '127.0.0.1' : uri.host;
    final isLocalHost =
        host == '127.0.0.1' || host == 'localhost' || host == '::1';
    if (!isLocalHost) {
      setState(() {
        _backendStatus = '目前 URL 是遠端後端，只能檢查連線，不能由本機啟動：$host';
      });
      return;
    }

    if (_backendProcess != null) {
      setState(() {
        _backendStatus = '本機後端已由此 UI 啟動，正在重新檢查狀態...';
      });
      await _checkBackendStatus();
      return;
    }

    setState(() {
      _isBackendBusy = true;
      _backendStatus = '正在啟動本地後端...';
    });

    try {
      final pythonCommand = _pythonController.text.trim().isEmpty
          ? defaultPythonCommand()
          : _pythonController.text.trim();
      final pythonCommandParts = splitCommandLine(pythonCommand);
      if (pythonCommandParts.isEmpty) {
        throw Exception('Python 指令不可為空。');
      }

      final backendPath = joinPath(root.path, 'scripts', 'local_backend.py');
      final port = uri.hasPort ? uri.port : 8765;
      final bindHost = host == 'localhost' ? '127.0.0.1' : host;
      final args = [
        ...pythonCommandParts.skip(1),
        backendPath,
        '--host',
        bindHost,
        '--port',
        port.toString(),
      ];
      final process = await Process.start(
        pythonCommandParts.first,
        args,
        workingDirectory: root.path,
        runInShell: false,
        environment: {
          'PYTHONIOENCODING': 'utf-8',
          'PYTHONUTF8': '1',
        },
      );
      _backendProcess = process;
      _backendOutputBuffer.clear();
      _listenToProcessOutput(
        process.stdout,
        onLine: (line) => _rememberBackendOutput(line),
      );
      _listenToProcessOutput(
        process.stderr,
        isError: true,
        onLine: (line) => _rememberBackendOutput('ERR  $line'),
      );
      process.exitCode.then((exitCode) {
        if (!mounted) {
          return;
        }
        if (_backendProcess != process) {
          return;
        }
        setState(() {
          _backendProcess = null;
          final detail = _backendOutputBuffer.isEmpty
              ? ''
              : '\n\n後端輸出：\n${_backendOutputBuffer.join('\n')}';
          _backendStatus = '本地後端已停止，exit code=$exitCode$detail';
        });
      });

      await Future<void>.delayed(const Duration(milliseconds: 800));
      await _checkBackendStatus();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _backendStatus = '啟動後端失敗：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBackendBusy = false;
        });
      }
    }
  }

  Future<void> _stopBackendProcesses() async {
    final backendUrl = _backendUrlController.text.trim().isEmpty
        ? _settings.backendBaseUrl
        : _backendUrlController.text.trim();
    final uri = Uri.parse(backendUrl);
    final host = uri.host.isEmpty ? '127.0.0.1' : uri.host;
    final isLocalHost =
        host == '127.0.0.1' || host == 'localhost' || host == '::1';
    if (!isLocalHost) {
      setState(() {
        _backendStatus = '目前 URL 是遠端後端，不能由本機關閉遠端 process：$host';
      });
      return;
    }

    setState(() {
      _isBackendBusy = true;
      _backendStatus = '正在查找並關閉佔用 Backend port 的 process...';
    });

    try {
      _backendProcess?.kill();
      _backendProcess = null;

      final port = uri.hasPort ? uri.port : 8765;
      if (!Platform.isWindows) {
        setState(() {
          _backendStatus =
              '目前僅實作 Windows process 關閉。請手動關閉佔用 port $port 的 process。';
        });
        return;
      }

      final netstat = await Process.run('netstat', ['-ano']);
      final stdoutText = netstat.stdout?.toString() ?? '';
      final pids = <String>{};
      for (final line in stdoutText.split(RegExp(r'\r?\n'))) {
        final normalized = line.trim().replaceAll(RegExp(r'\s+'), ' ');
        if (!normalized.contains(':$port') ||
            !normalized.contains('LISTENING')) {
          continue;
        }
        final parts = normalized.split(' ');
        final pid = parts.isEmpty ? '' : parts.last.trim();
        if (RegExp(r'^\d+$').hasMatch(pid) && pid != '0' && pid != '4') {
          pids.add(pid);
        }
      }

      if (pids.isEmpty) {
        setState(() {
          _backendStatus = '找不到佔用 127.0.0.1:$port 的 LISTENING process。';
        });
        return;
      }

      final results = <String>[];
      for (final pid in pids) {
        final result = await Process.run('taskkill', ['/PID', pid, '/F']);
        final output = [
          result.stdout?.toString().trim() ?? '',
          result.stderr?.toString().trim() ?? '',
        ].where((text) => text.isNotEmpty).join('\n');
        results.add(
            'PID $pid -> exit ${result.exitCode}${output.isEmpty ? '' : '\n$output'}');
      }

      setState(() {
        _backendStatus =
            '已嘗試關閉佔用 port $port 的 process：\n${results.join('\n\n')}';
      });
    } catch (error) {
      setState(() {
        _backendStatus = '關閉舊 process 失敗：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBackendBusy = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    final root = _projectRoot;
    if (root == null) {
      return;
    }

    final updated = AppSettings(
      notesRootPath: _notesRootController.text.trim(),
      backendBaseUrl: _backendUrlController.text.trim(),
      ollamaBaseUrl: _ollamaUrlController.text.trim(),
      ollamaModel: _ollamaModelController.text.trim(),
      ollamaApiKey: _ollamaApiKeyController.text.trim(),
      svnCommand: _svnCommandController.text.trim(),
      svnCommandParameters: _svnParametersController.text.trim(),
      pythonCommand: _pythonController.text.trim(),
      languageCode: _languageCode,
      appearanceThemeCode: _appearanceThemeCode,
      repositories: _repositoryProfiles,
      branchMapOrientation: _settings.branchMapOrientation,
    );
    try {
      await saveAppSettings(root, updated);
      if (!mounted) {
        return;
      }
      final nextSelected =
          matchRepository(updated.repositories, _selectedRepository) ??
              updated.repositories.first;
      final nextData = nextSelected.name == _selectedRepository.name
          ? _data
          : await readOutput(root, nextSelected);
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = updated;
        _repositoryProfiles = updated.repositories;
        _selectedRepository = nextSelected;
        _data = nextData;
        _branchCommitsPath = null;
        _commitListExpandedRevision = null;
        _branchCommitsMarkdownTab = false;
        _showSettings = false;
        _showRepositoryProfiles = false;
        _lastUpdateStatus = '設定已儲存';
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    }
  }

  Future<void> _persistBranchMapOrientation(int orientation) async {
    final root = _projectRoot;
    if (root == null) {
      return;
    }
    final updated =
        _settings.copyWith(branchMapOrientation: orientation);
    try {
      await saveAppSettings(root, updated);
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = updated;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    }
  }

  Future<void> _selectRepository(SvnRepository repository) async {
    if (_isRefreshing) {
      return;
    }
    setState(() {
      _selectedRepository = repository;
      _branchCommitsPath = null;
      _commitListExpandedRevision = null;
      _branchCommitsMarkdownTab = false;
      _error = null;
      _lastUpdateStatus = '正在讀取本地輸出資料';
    });
    await _reloadData();
    unawaited(_checkRepositoryUpdateInBackground(repository));
  }

  Future<void> _checkRepositoryUpdateInBackground(
    SvnRepository repository,
  ) async {
    final token = ++_repoUpdateCheckToken;
    final localRevision = _data.latestCommit?.revision;
    try {
      if (mounted && repository.name == _selectedRepository.name) {
        setState(() {
          _lastUpdateStatus = t(
            context,
            '正在背景檢查遠端是否有更新',
            'Checking remote updates in background',
          );
        });
      }
      final remoteRevision = await _fetchRemoteHeadRevision(repository);
      if (!mounted ||
          token != _repoUpdateCheckToken ||
          repository.name != _selectedRepository.name) {
        return;
      }

      if (localRevision == null || localRevision <= 0) {
        setState(() {
          _lastUpdateStatus = t(
            context,
            '遠端已有資料，尚無本地 revision，建議執行增量更新',
            'Remote data exists, no local revision yet. Incremental update is recommended.',
          );
        });
        _showRepositoryUpdateSnackBar(
          repository: repository,
          message: t(
            context,
            '${repository.name} 尚無本地資料，遠端 HEAD 為 r$remoteRevision，建議執行增量更新。',
            '${repository.name} has no local data. Remote HEAD is r$remoteRevision. Incremental update is recommended.',
          ),
        );
        return;
      }

      if (remoteRevision > localRevision) {
        setState(() {
          _lastUpdateStatus = t(
            context,
            '遠端有較新的 revision，建議更新',
            'Newer remote revision found. Update recommended.',
          );
        });
        _showRepositoryUpdateSnackBar(
          repository: repository,
          message: t(
            context,
            '${repository.name} 需要更新：本地 r$localRevision，遠端 r$remoteRevision。',
            '${repository.name} needs update: local r$localRevision, remote r$remoteRevision.',
          ),
        );
      } else {
        setState(() {
          _lastUpdateStatus = t(
            context,
            '遠端檢查完成，目前已是最新',
            'Remote check complete. Local data is up to date.',
          );
        });
      }
    } catch (error) {
      if (!mounted ||
          token != _repoUpdateCheckToken ||
          repository.name != _selectedRepository.name) {
        return;
      }
      setState(() {
        _lastUpdateStatus = t(
          context,
          '遠端更新檢查失敗',
          'Remote update check failed',
        );
      });
    }
  }

  Future<int> _fetchRemoteHeadRevision(SvnRepository repository) async {
    final svnCommand = _svnCommandController.text.trim().isEmpty
        ? defaultSvnCommand()
        : _svnCommandController.text.trim();
    final svnCommandParts = splitCommandLine(svnCommand);
    if (svnCommandParts.isEmpty) {
      throw Exception('SVN Command 不可為空。');
    }

    final extraSvnArgs = _svnParametersController.text.trim().isEmpty
        ? splitCommandLine(defaultSvnParameters())
        : splitCommandLine(_svnParametersController.text.trim());
    final args = [
      ...svnCommandParts.skip(1),
      'info',
      '--xml',
      ...extraSvnArgs,
      if (_usernameController.text.trim().isNotEmpty) ...[
        '--username',
        _usernameController.text.trim(),
      ],
      if (_passwordController.text.isNotEmpty) ...[
        '--password',
        _passwordController.text,
      ],
      repository.url,
    ];
    final result = await Process.run(
      svnCommandParts.first,
      args,
      workingDirectory: _projectRoot?.path,
      runInShell: false,
    );
    final stdoutText = result.stdout?.toString() ?? '';
    final stderrText = result.stderr?.toString() ?? '';
    if (result.exitCode != 0) {
      throw Exception(stderrText.trim().isEmpty ? stdoutText : stderrText);
    }

    final match = RegExp(r'revision="(\d+)"').firstMatch(stdoutText);
    final revision = int.tryParse(match?.group(1) ?? '');
    if (revision == null || revision <= 0) {
      throw Exception('Unable to parse SVN HEAD revision.');
    }
    return revision;
  }

  void _showRepositoryUpdateSnackBar({
    required SvnRepository repository,
    required String message,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: t(context, '更新', 'Update'),
          onPressed: () {
            if (repository.name == _selectedRepository.name) {
              unawaited(_runUpdate());
            }
          },
        ),
      ),
    );
  }

  Future<void> _reloadData() async {
    final root = _projectRoot;
    if (root == null) {
      return;
    }
    try {
      final data = await readOutput(root, _selectedRepository);
      if (!mounted) {
        return;
      }
      setState(() {
        _data = data;
        _lastUpdateStatus = data.isEmpty ? '尚無本地資料' : '已載入本地資料';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    }
  }

  Future<void> _runUpdate() async {
    final root = _projectRoot;
    if (root == null || _isRefreshing) {
      return;
    }

    setState(() {
      _isRefreshing = true;
      _error = null;
      _lastUpdateStatus = '正在執行 SVN 增量更新';
      _outputConsoleExpanded = true;
      _logs.clear();
    });

    try {
      final configPath = await _writeRuntimeConfig(root, _selectedRepository);
      final loaderPath = joinPath(root.path, 'scripts', 'svn_to_ai_loader.py');
      final pythonCommand = _pythonController.text.trim().isEmpty
          ? defaultPythonCommand()
          : _pythonController.text.trim();
      final pythonCommandParts = splitCommandLine(pythonCommand);
      if (pythonCommandParts.isEmpty) {
        throw Exception('Python 指令不可為空。');
      }
      setState(() {
        _logs.add(
          'RUN  ${pythonCommandParts.join(' ')} "$loaderPath" "$configPath"',
        );
      });
      final process = await Process.start(
        pythonCommandParts.first,
        [...pythonCommandParts.skip(1), loaderPath, configPath],
        workingDirectory: root.path,
        runInShell: false,
        environment: {
          'PYTHONIOENCODING': 'utf-8',
          'PYTHONUTF8': '1',
        },
      );

      final stdoutDone = _listenToProcessOutput(process.stdout);
      final stderrDone = _listenToProcessOutput(process.stderr, isError: true);
      final exitCode = await process.exitCode;
      await Future.wait([stdoutDone, stderrDone]);

      if (exitCode != 0) {
        throw Exception('更新失敗，exit code=$exitCode。請查看執行紀錄。');
      }

      final data = await readOutput(root, _selectedRepository);
      if (!mounted) {
        return;
      }
      setState(() {
        _data = data;
        _lastUpdateStatus = '更新完成，已重新載入資料';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _lastUpdateStatus = '更新未完成';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _listenToProcessOutput(
    Stream<List<int>> stream, {
    bool isError = false,
    void Function(String line)? onLine,
  }) {
    return stream
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) {
      if (!mounted) {
        return;
      }
      onLine?.call(line);
      setState(() {
        _logs.add(isError ? 'ERR  $line' : line);
      });
    }).asFuture<void>();
  }

  void _rememberBackendOutput(String line) {
    _backendOutputBuffer.add(line);
    if (_backendOutputBuffer.length > 20) {
      _backendOutputBuffer.removeAt(0);
    }
  }

  String _formatBackendConnectionError(Object error) {
    final text = error.toString();
    if (text.contains('Connection closed before full header') ||
        text.contains('Connection closed while receiving data')) {
      return '後端連線被提早關閉：$text\n\n'
          '可能原因：127.0.0.1:8765 上有殘留/非預期的 process，或後端啟動後立即崩潰。'
          '請關閉舊的 local_backend.py 後重新啟動，或把 Backend URL 改到其他 port（例如 http://127.0.0.1:8766）再按「啟動本地後端」。';
    }
    return '後端未連線：$text';
  }

  Future<String> _writeRuntimeConfig(
    Directory root,
    SvnRepository repository,
  ) async {
    final configDir = Directory(joinPath(root.path, '.runtime_configs'));
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }

    final outputDir = joinPath(
      joinPath(root.path, 'svn_ai_output'),
      repository.name,
    );
    final svnExecutable = _svnCommandController.text.trim().isEmpty
        ? defaultSvnCommand()
        : _svnCommandController.text.trim();
    final extraSvnArgs = _svnParametersController.text.trim().isEmpty
        ? splitCommandLine(defaultSvnParameters())
        : splitCommandLine(_svnParametersController.text.trim());
    final config = {
      'svn_url': repository.url,
      'username': _usernameController.text.trim(),
      'password': _passwordController.text,
      'output_dir': outputDir,
      'svn_executable': svnExecutable,
      'extra_svn_args': extraSvnArgs,
      'ticket_regex': r'([A-Z][A-Z0-9]+-\d+|[A-Z]{2,}\d{3,}|#\d+)',
      'start_revision': 1,
    };

    final configFile =
        File(joinPath(configDir.path, '${repository.name}.json'));
    await configFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config),
      encoding: utf8,
    );
    return configFile.path;
  }

  @override
  Widget build(BuildContext context) {
    Widget consoleWidget() => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          child: OutputConsole(
            logs: _logs,
            expanded: _outputConsoleExpanded,
            onToggleExpanded: () {
              setState(() {
                _outputConsoleExpanded = !_outputConsoleExpanded;
              });
            },
          ),
        );

    final Widget shellContent = _isInitializing
        ? const Center(child: CircularProgressIndicator())
        : LayoutBuilder(
            builder: (context, constraints) {
              if (_showSettings) {
                return Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _buildSettingsPage(),
                      ),
                    ),
                    consoleWidget(),
                  ],
                );
              }

              if (_showRepositoryProfiles) {
                return Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _buildRepositoryProfilesPage(),
                      ),
                    ),
                    consoleWidget(),
                  ],
                );
              }

              if (_showAiAnalysis) {
                return Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _buildAiAnalysisPage(),
                      ),
                    ),
                    consoleWidget(),
                  ],
                );
              }

              if (_showAiHistory) {
                return Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _buildAiHistoryPage(),
                      ),
                    ),
                    consoleWidget(),
                  ],
                );
              }

              if (_showAiChat) {
                return Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _buildAiChatPage(),
                      ),
                    ),
                    consoleWidget(),
                  ],
                );
              }

              if (_branchCommitsPath != null) {
                return Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _buildBranchCommitsPage(_branchCommitsPath!),
                      ),
                    ),
                    consoleWidget(),
                  ],
                );
              }

              if (_showVisualMap) {
                return Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _buildVisualMapPage(),
                      ),
                    ),
                    consoleWidget(),
                  ],
                );
              }

              final isCompact = constraints.maxWidth < 1000;
              if (isCompact) {
                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            SizedBox(height: 820, child: _buildControlPanel()),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 900,
                              child: _buildDataPanel(isCompact: true),
                            ),
                          ],
                        ),
                      ),
                    ),
                    consoleWidget(),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      left: MediaQuery.viewPaddingOf(context).left,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      width: _controlPanelCollapsed ? 80 : 304,
                      child: _buildControlPanel(),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: _buildDataPanel(isCompact: false),
                        ),
                        consoleWidget(),
                      ],
                    ),
                  ),
                ],
              );
            },
          );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: isNightAppearance(_appearanceThemeCode)
                  ? cyberBackground
                  : dayBackground,
            ),
          ),
          LanguageScope(
            languageCode: _languageCode,
            child: SafeArea(
              left: false,
              child: shellContent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualMapPage() {
    final repo = _selectedRepository;
    final nodeCount = _data.topology.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuraBackPageHeader(
          onBack: () {
            setState(() {
              _showVisualMap = false;
            });
          },
          title: t(context, '分支視覺地圖', 'Visual Branch Map'),
          subtitle: t(
            context,
            '${repo.name} · $nodeCount 個節點',
            '${repo.name} · $nodeCount nodes',
          ),
        ),
        Expanded(
          child: BranchMapView(
            repository: repo,
            data: _data,
            settings: _settings,
            onBranchSelected: _openBranchDetail,
            onBranchMapOrientationChanged: (orientation) {
              unawaited(_persistBranchMapOrientation(orientation));
            },
            showTitleOverlay: false,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuraBackPageHeader(
          onBack: () {
            setState(() {
              _showSettings = false;
            });
          },
          title: t(context, '設定', 'Settings'),
          subtitle: t(
            context,
            '後端、Ollama、SVN 與筆記路徑',
            'Backend, Ollama, SVN, and notes paths',
          ),
          trailing: FilledButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save_rounded),
            label: Text(t(context, '儲存設定', 'Save Settings')),
          ),
        ),
        Expanded(
          child: SettingsView(
            settings: _settings,
            usernameController: _usernameController,
            passwordController: _passwordController,
            notesRootController: _notesRootController,
            backendUrlController: _backendUrlController,
            ollamaUrlController: _ollamaUrlController,
            ollamaModelController: _ollamaModelController,
            ollamaApiKeyController: _ollamaApiKeyController,
            svnCommandController: _svnCommandController,
            svnParametersController: _svnParametersController,
            pythonController: _pythonController,
            languageCode: _languageCode,
            onLanguageChanged: (value) {
              setState(() {
                _languageCode = value;
              });
            },
            appearanceThemeCode: _appearanceThemeCode,
            onAppearanceThemeChanged: (value) {
              setState(() {
                _appearanceThemeCode = value;
              });
              appearanceThemeNotifier.value = value;
            },
            backendStatus: _backendStatus,
            isBackendBusy: _isBackendBusy,
            onSave: _saveSettings,
            onClose: () {
              setState(() {
                _showSettings = false;
              });
            },
            onCheckBackend: _checkBackendStatus,
            onStartBackend: _startBackend,
            onStopBackendProcesses: _stopBackendProcesses,
            onTestOllama: _testOllamaSettings,
            isOllamaTestBusy: _ollamaTestBusy,
          ),
        ),
      ],
    );
  }

  Widget _buildRepositoryProfilesPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuraBackPageHeader(
          onBack: () {
            setState(() {
              _showRepositoryProfiles = false;
            });
          },
          title: t(context, 'Repository Profiles', 'Repository Profiles'),
          subtitle: t(
            context,
            '管理 SVN 庫清單',
            'Manage the SVN repository list',
          ),
          trailing: FilledButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save_rounded),
            label: Text(t(context, '儲存設定', 'Save Settings')),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 28),
            child: SettingsSectionCard(
              icon: Icons.storage_rounded,
              title: 'Repository Profiles',
              description: t(
                context,
                '可新增或刪除 SVN 庫。Title 與 SVN Base URL 必填；Sub Title 可留空。儲存後會套用設定並返回主頁。',
                'Add or remove SVN repositories. Title and SVN Base URL are required; Sub Title is optional. Saving applies settings and returns to the home page.',
              ),
              children: [
                RepositoryProfilesEditor(
                  repositories: _repositoryProfiles,
                  onChanged: (profiles) {
                    setState(() {
                      _repositoryProfiles = profiles;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAiAnalysisPage() {
    return ProjectReportAnalysisPage(
      repository: _selectedRepository,
      settings: _settings,
      titleController: _aiReportTitleController,
      promptController: _aiPromptController,
      onBack: () {
        setState(() {
          _showAiAnalysis = false;
        });
      },
    );
  }

  Widget _buildAiHistoryPage() {
    return ProjectReportHistoryPage(
      repository: _selectedRepository,
      settings: _settings,
      onBack: () {
        setState(() {
          _showAiHistory = false;
        });
      },
    );
  }

  Widget _buildAiChatPage() {
    return ProjectChatPage(
      repository: _selectedRepository,
      settings: _settings,
      onBack: () {
        setState(() {
          _showAiChat = false;
        });
      },
    );
  }

  void _openBranchDetail(String branchPath) {
    setState(() {
      _branchCommitsPath = branchPath;
      _commitListExpandedRevision = null;
      _branchCommitsMarkdownTab = false;
    });
  }

  Widget _buildBranchCommitsPage(String branchPath) {
    final node = _data.topology[branchPath];
    final commits = filterCommitsForBranch(_data, branchPath, node);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuraBackPageHeader(
          onBack: () {
            setState(() {
              _branchCommitsPath = null;
              _commitListExpandedRevision = null;
              _branchCommitsMarkdownTab = false;
            });
          },
          title: t(context, '分支詳情', 'Branch Detail'),
          subtitleWidget: SelectableText(
            branchPath,
            style: GoogleFonts.jetBrainsMono(
              color: aura(context).textMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                showSelectedIcon: false,
                emptySelectionAllowed: false,
                segments: [
                  ButtonSegment<bool>(
                    value: false,
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        t(context, 'Commit 列表', 'Commit List'),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        t(context, 'Markdown 筆記', 'Markdown Note'),
                      ),
                    ),
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                  ),
                ],
                selected: {_branchCommitsMarkdownTab},
                onSelectionChanged: (Set<bool> selection) {
                  if (selection.isEmpty) {
                    return;
                  }
                  setState(() {
                    _branchCommitsMarkdownTab = selection.first;
                  });
                },
              ),
              const SizedBox(width: 12),
              Chip(
                avatar: const Icon(Icons.receipt_long_rounded, size: 18),
                label: Text('${commits.length} commits'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _branchCommitsMarkdownTab
              ? BranchNoteEditor(
                  repository: _selectedRepository,
                  settings: _settings,
                  branchPath: branchPath,
                  expanded: true,
                )
              : Builder(
                  builder: (context) {
                    final dark =
                        Theme.of(context).brightness == Brightness.dark;
                    final auraTokens = aura(context);
                    final list = commits.isEmpty
                        ? Center(
                            child: Text(
                              t(
                                context,
                                '找不到此 branch 相關 commit。',
                                'No commits found for this branch.',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.fromLTRB(
                              dark ? 12 : 8,
                              dark ? 16 : 4,
                              12,
                              dark ? 28 : 4,
                            ),
                            itemCount: commits.length,
                            itemBuilder: (context, index) {
                              final commit = commits[index];
                              final rev = commit.revision;
                              return CommitTimelineItem(
                                commit: commit,
                                repository: _selectedRepository,
                                settings: _settings,
                                expanded:
                                    _commitListExpandedRevision == rev,
                                onExpandToggle: () {
                                  setState(() {
                                    _commitListExpandedRevision =
                                        _commitListExpandedRevision == rev
                                            ? null
                                            : rev;
                                  });
                                },
                              );
                            },
                          );
                    if (!dark) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                          child: list,
                        ),
                      );
                    }
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: stitchSurfaceDim,
                        border: Border(
                          right: BorderSide(
                            color: auraTokens.border.withOpacity(0.22),
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    t(context, 'Commit 歷史', 'Commit History'),
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: auraTokens.text,
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.filter_list_rounded,
                                      size: 16,
                                      color: auraTokens.textSubtle,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'FILTER',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11,
                                        letterSpacing: 0.6,
                                        fontWeight: FontWeight.w500,
                                        color: auraTokens.textSubtle,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 1,
                            color: auraTokens.border.withOpacity(0.1),
                          ),
                          Expanded(child: list),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildControlPanel() {
    return ControlPanel(
      selectedRepository: _selectedRepository,
      repositories: _repositoryProfiles,
      isRefreshing: _isRefreshing,
      status: _lastUpdateStatus,
      rootPath: _projectRoot?.path ??
          t(context, '未找到專案根目錄', 'Project root not found'),
      collapsed: _controlPanelCollapsed,
      onToggleCollapsed: () {
        setState(() {
          _controlPanelCollapsed = !_controlPanelCollapsed;
        });
      },
      onRepositorySelected: _selectRepository,
      onUpdatePressed: _runUpdate,
      onRepositoryProfilesPressed: () {
        setState(() {
          _showRepositoryProfiles = true;
        });
      },
      onSettingsPressed: () {
        setState(() {
          _showSettings = true;
        });
      },
    );
  }

  Widget _buildDataPanel({required bool isCompact}) {
    return DataPanel(
      repository: _selectedRepository,
      data: _data,
      error: _error,
      isCompact: isCompact,
      showVisualMap: _showVisualMap,
      settings: _settings,
      backendStatus: _backendStatus,
      onCheckBackend: _checkBackendStatus,
      onStartBackend: _startBackend,
      onVisualMapChanged: (value) {
        setState(() {
          _showVisualMap = value;
        });
      },
      onAiAnalysisPressed: () {
        setState(() {
          _showAiAnalysis = true;
        });
      },
      onAiHistoryPressed: () {
        setState(() {
          _showAiHistory = true;
        });
      },
      onAiChatPressed: () {
        setState(() {
          _showAiChat = true;
        });
      },
      onBranchSelected: _openBranchDetail,
      onBranchMapOrientationChanged: (orientation) {
        unawaited(_persistBranchMapOrientation(orientation));
      },
    );
  }
}
