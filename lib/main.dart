import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:graphview/GraphView.dart' as graphview;

import 'aura_theme.dart';
import 'localization.dart';
import 'models.dart';
import 'notes_store.dart';
import 'settings_view.dart';
import 'utils.dart';

export 'aura_theme.dart' show _aura, _appearanceThemeNotifier;
export 'localization.dart' show _t;
export 'models.dart' show SvnRepository, AppData, BranchNode, CommitRecord,
    ChangedPath, RevisionDiffResult, BranchNoteDocument, ProjectReportResult,
    ProjectReportLogEntry;
export 'notes_store.dart' show AppSettings, _defaultRepositories,
    _loadAppSettings, _saveAppSettings, _loadBranchNote, _saveBranchNote,
    _generateProjectReportStream, _loadProjectReportHistory, _loadRevisionDiff;
export 'utils.dart' show _joinPath, _fileName, _splitCommandLine, _parseCsv,
    _findProjectRoot, _readOutput, _readCommitCsv, _actionColor, _shortCommitDate,
    _backendStatusSummary, _backendStatusStyle, _parseUnifiedDiff;

part 'branch_map_painter.dart';

void main() {
  runApp(const SvnBranchViewerApp());
}

class SvnBranchViewerApp extends StatelessWidget {
  const SvnBranchViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: _appearanceThemeNotifier,
      builder: (context, appearanceThemeCode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Aura SVN',
          theme: _buildAuraThemeData(appearanceThemeCode),
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
  SvnRepository _selectedRepository = _defaultRepositories.first;
  List<SvnRepository> _repositoryProfiles = List.of(_defaultRepositories);
  AppData _data = AppData.empty();
  Directory? _projectRoot;
  bool _isInitializing = true;
  bool _isRefreshing = false;
  bool _showVisualMap = false;
  bool _showSettings = false;
  bool _showRepositoryProfiles = false;
  bool _showAiAnalysis = false;
  bool _showAiHistory = false;
  bool _controlPanelCollapsed = false;
  bool _outputConsoleExpanded = false;
  String? _branchCommitsPath;
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
    repositories: _defaultRepositories,
  );
  Process? _backendProcess;
  bool _isBackendBusy = false;
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
      final root = await _findProjectRoot();
      final settings = await _loadAppSettings(root);
      final repositories = settings.repositories;
      final selectedRepository = repositories.first;
      final data = await _readOutput(root, selectedRepository);
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
        _appearanceThemeNotifier.value = settings.appearanceThemeCode;
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
              '後端已連線 (${response.statusCode})，Ollama API key：${keyLoaded ? '已載入' : '未載入'}';
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
          ? _defaultPythonCommand()
          : _pythonController.text.trim();
      final pythonCommandParts = _splitCommandLine(pythonCommand);
      if (pythonCommandParts.isEmpty) {
        throw Exception('Python 指令不可為空。');
      }

      final backendPath = _joinPath(root.path, 'scripts', 'local_backend.py');
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
    );
    try {
      await _saveAppSettings(root, updated);
      if (!mounted) {
        return;
      }
      final nextSelected =
          _matchRepository(updated.repositories, _selectedRepository) ??
              updated.repositories.first;
      final nextData = nextSelected.name == _selectedRepository.name
          ? _data
          : await _readOutput(root, nextSelected);
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = updated;
        _repositoryProfiles = updated.repositories;
        _selectedRepository = nextSelected;
        _data = nextData;
        _branchCommitsPath = null;
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

  Future<void> _selectRepository(SvnRepository repository) async {
    if (_isRefreshing) {
      return;
    }
    setState(() {
      _selectedRepository = repository;
      _branchCommitsPath = null;
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
          _lastUpdateStatus = _t(
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
          _lastUpdateStatus = _t(
            context,
            '遠端已有資料，尚無本地 revision，建議執行增量更新',
            'Remote data exists, no local revision yet. Incremental update is recommended.',
          );
        });
        _showRepositoryUpdateSnackBar(
          repository: repository,
          message: _t(
            context,
            '${repository.name} 尚無本地資料，遠端 HEAD 為 r$remoteRevision，建議執行增量更新。',
            '${repository.name} has no local data. Remote HEAD is r$remoteRevision. Incremental update is recommended.',
          ),
        );
        return;
      }

      if (remoteRevision > localRevision) {
        setState(() {
          _lastUpdateStatus = _t(
            context,
            '遠端有較新的 revision，建議更新',
            'Newer remote revision found. Update recommended.',
          );
        });
        _showRepositoryUpdateSnackBar(
          repository: repository,
          message: _t(
            context,
            '${repository.name} 需要更新：本地 r$localRevision，遠端 r$remoteRevision。',
            '${repository.name} needs update: local r$localRevision, remote r$remoteRevision.',
          ),
        );
      } else {
        setState(() {
          _lastUpdateStatus = _t(
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
        _lastUpdateStatus = _t(
          context,
          '遠端更新檢查失敗',
          'Remote update check failed',
        );
      });
    }
  }

  Future<int> _fetchRemoteHeadRevision(SvnRepository repository) async {
    final svnCommand = _svnCommandController.text.trim().isEmpty
        ? _defaultSvnCommand()
        : _svnCommandController.text.trim();
    final svnCommandParts = _splitCommandLine(svnCommand);
    if (svnCommandParts.isEmpty) {
      throw Exception('SVN Command 不可為空。');
    }

    final extraSvnArgs = _svnParametersController.text.trim().isEmpty
        ? _splitCommandLine(_defaultSvnParameters())
        : _splitCommandLine(_svnParametersController.text.trim());
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
          label: _t(context, '更新', 'Update'),
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
      final data = await _readOutput(root, _selectedRepository);
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
      final loaderPath = _joinPath(root.path, 'scripts', 'svn_to_ai_loader.py');
      final pythonCommand = _pythonController.text.trim().isEmpty
          ? _defaultPythonCommand()
          : _pythonController.text.trim();
      final pythonCommandParts = _splitCommandLine(pythonCommand);
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

      final data = await _readOutput(root, _selectedRepository);
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
    final configDir = Directory(_joinPath(root.path, '.runtime_configs'));
    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }

    final outputDir = _joinPath(
      _joinPath(root.path, 'svn_ai_output'),
      repository.name,
    );
    final svnExecutable = _svnCommandController.text.trim().isEmpty
        ? _defaultSvnCommand()
        : _svnCommandController.text.trim();
    final extraSvnArgs = _svnParametersController.text.trim().isEmpty
        ? _splitCommandLine(_defaultSvnParameters())
        : _splitCommandLine(_svnParametersController.text.trim());
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
        File(_joinPath(configDir.path, '${repository.name}.json'));
    await configFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(config),
      encoding: utf8,
    );
    return configFile.path;
  }

  @override
  Widget build(BuildContext context) {
    final body = _isInitializing
        ? const Center(child: CircularProgressIndicator())
        : LayoutBuilder(
            builder: (context, constraints) {
              if (_showSettings) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildSettingsPage(),
                );
              }

              if (_showRepositoryProfiles) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildRepositoryProfilesPage(),
                );
              }

              if (_showAiAnalysis) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildAiAnalysisPage(),
                );
              }

              if (_showAiHistory) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildAiHistoryPage(),
                );
              }

              if (_branchCommitsPath != null) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildBranchCommitsPage(_branchCommitsPath!),
                );
              }

              if (_showVisualMap) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildVisualMapPage(),
                );
              }

              final isCompact = constraints.maxWidth < 1000;
              if (isCompact) {
                return SingleChildScrollView(
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
                );
              }

              return Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      width: _controlPanelCollapsed ? 78 : 360,
                      child: _buildControlPanel(),
                    ),
                    const SizedBox(width: 20),
                    Expanded(child: _buildDataPanel(isCompact: false)),
                  ],
                ),
              );
            },
          );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _isNightAppearance(_appearanceThemeCode)
                ? const _CyberSpaceBackground()
                : const _DayAuraBackground(),
          ),
          LanguageScope(
            languageCode: _languageCode,
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(child: body),
                  if (!_isInitializing)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
                      child: _OutputConsole(
                        logs: _logs,
                        expanded: _outputConsoleExpanded,
                        onToggleExpanded: () {
                          setState(() {
                            _outputConsoleExpanded = !_outputConsoleExpanded;
                          });
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualMapPage() {
    return Stack(
      children: [
        Positioned.fill(
          child: BranchMapView(
            repository: _selectedRepository,
            data: _data,
            settings: _settings,
            onBranchSelected: _showBranchCommitPreview,
          ),
        ),
        Positioned(
          top: 18,
          right: 18,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _showVisualMap = false;
                  });
                },
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(_t(context, '返回主頁', 'Back to Home')),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: _t(context, '返回主頁', 'Back to Home'),
                  onPressed: () {
                    setState(() {
                      _showSettings = false;
                    });
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _t(context, '設定', 'Settings'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(_t(context, '儲存設定', 'Save Settings')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
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
              _appearanceThemeNotifier.value = value;
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
          ),
        ),
      ],
    );
  }

  Widget _buildRepositoryProfilesPage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: _t(context, '返回主頁', 'Back to Home'),
                  onPressed: () {
                    setState(() {
                      _showRepositoryProfiles = false;
                    });
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Repository Profiles',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save_rounded),
                  label: Text(_t(context, '儲存設定', 'Save Settings')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 28),
            child: _SettingsSectionCard(
              icon: Icons.storage_rounded,
              title: 'Repository Profiles',
              description: _t(
                context,
                '可新增或刪除 SVN 庫。Title 與 SVN Base URL 必填；Sub Title 可留空。儲存後會套用設定並返回主頁。',
                'Add or remove SVN repositories. Title and SVN Base URL are required; Sub Title is optional. Saving applies settings and returns to the home page.',
              ),
              children: [
                _RepositoryProfilesEditor(
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

  Future<void> _showBranchCommitPreview(String branchPath) async {
    final node = _data.topology[branchPath];
    final commits = _filterCommitsForBranch(_data, branchPath, node);
    final openDetail = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => LanguageScope(
        languageCode: _languageCode,
        child: _BranchCommitPreviewDialog(
          branchPath: branchPath,
          commits: commits,
        ),
      ),
    );
    if (!mounted || openDetail != true) {
      return;
    }
    setState(() {
      _branchCommitsPath = branchPath;
    });
  }

  Widget _buildBranchCommitsPage(String branchPath) {
    final node = _data.topology[branchPath];
    final commits = _filterCommitsForBranch(_data, branchPath, node);

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: _t(context, '返回', 'Back'),
                    onPressed: () {
                      setState(() {
                        _branchCommitsPath = null;
                      });
                    },
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t(context, '分支詳情', 'Branch Detail'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SelectableText(
                          branchPath,
                          style: TextStyle(
                            color: _aura(context).textMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Chip(
                    avatar: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: Text('${commits.length} commits'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: TabBar(
              tabs: [
                Tab(
                    icon: const Icon(Icons.receipt_long_rounded),
                    text: _t(context, 'Commit 列表', 'Commit List')),
                Tab(
                  icon: const Icon(Icons.edit_note_rounded),
                  text: _t(context, 'Markdown 筆記', 'Markdown Note'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: TabBarView(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: commits.isEmpty
                        ? Center(
                            child: Text(_t(
                              context,
                              '找不到此 branch 相關 commit。',
                              'No commits found for this branch.',
                            )),
                          )
                        : ListView.separated(
                            itemCount: commits.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) => _CommitTile(
                              commit: commits[index],
                              repository: _selectedRepository,
                              settings: _settings,
                            ),
                          ),
                  ),
                ),
                BranchNoteEditor(
                  repository: _selectedRepository,
                  settings: _settings,
                  branchPath: branchPath,
                  expanded: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlPanel() {
    return _ControlPanel(
      selectedRepository: _selectedRepository,
      repositories: _repositoryProfiles,
      isRefreshing: _isRefreshing,
      status: _lastUpdateStatus,
      rootPath: _projectRoot?.path ??
          _t(context, '未找到專案根目錄', 'Project root not found'),
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
    return _DataPanel(
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
      onBranchSelected: _showBranchCommitPreview,
    );
  }
}
