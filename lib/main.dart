import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:graphview/GraphView.dart' as graphview;

part 'branch_map_painter.dart';
part 'branch_map_view.dart';
part 'notes_store.dart';
part 'project_report_view.dart';
part 'settings_view.dart';

const _svnTrustArg =
    '--trust-server-cert-failures=unknown-ca,cn-mismatch,expired,not-yet-valid,other';
const _cyberBackground = Color(0xFF0D1515);
const _cyberSurface = Color(0xE6192122);
const _cyberSurfaceAlt = Color(0xFF232B2C);
const _cyberSurfaceSoft = Color(0xFF151D1E);
const _cyberAccent = Color(0xFF00DBE7);
const _cyberViolet = Color(0xFFEBB2FF);
const _cyberText = Color(0xFFDCE4E4);
const _cyberTextMuted = Color(0xFFB9CACB);
const _cyberTextSubtle = Color(0xFF849495);
const _cyberBorder = Color(0xFF3A494B);

const _dayBackground = Color(0xFFF5F7FB);
const _daySurface = Color(0xF0FFFFFF);
const _daySurfaceAlt = Color(0xFFF8FAFC);
const _daySurfaceSoft = Color(0xFFEFF6FF);
const _dayAccent = Color(0xFF2563EB);
const _dayViolet = Color(0xFF7C3AED);
const _dayText = Color(0xFF0F172A);
const _dayTextMuted = Color(0xFF475569);
const _dayTextSubtle = Color(0xFF64748B);
const _dayBorder = Color(0xFFE2E8F0);

/// code.html (Stitch) — surface-container-high, surface-dim, primary-fixed
const _stitchSurfaceContainerHigh = Color(0xFF232B2C);
const _stitchSurfaceDim = Color(0xFF0D1515);
const _stitchPrimaryFixed = Color(0xFF74F5FF);
const _stitchGlassFill = Color(0xFF0D1515);
const _stitchGlassBorder = Color(0x1AFFFFFF);

/// 頂部儀表條左邊框強調色（Commits → Nodes → Backend → Author）
const _metricStripLeftCommits = Color(0xFF836A91);
const _metricStripLeftNodes = Color(0xFF71EEF8);
const _metricStripLeftBackend = Color(0xFFFFB86B);
const _metricStripLeftAuthor = Color(0xFFFF6B9D);

final _appearanceThemeNotifier = ValueNotifier<String>('night');

const _defaultRepositories = [
  SvnRepository('ET1288_AP', 'https://svn1.embestor.local/svn/ET1288_AP'),
  SvnRepository('ET1289_AP', 'https://svn1.embestor.local/svn/ET1289_AP'),
  SvnRepository('ET1290_AP', 'https://svn1.embestor.local/svn/ET1290_AP'),
];

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

ThemeData _buildAuraThemeData(String appearanceThemeCode) {
  final night = _isNightAppearance(appearanceThemeCode);
  final colors = night ? AuraThemeColors.night : AuraThemeColors.day;
  final scheme = ColorScheme.fromSeed(
    seedColor: colors.accent,
    brightness: night ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: colors.accent,
    secondary: colors.violet,
    surface: colors.surfaceAlt,
    onSurface: colors.text,
    outline: colors.border,
  );
  final base = night ? ThemeData.dark() : ThemeData.light();
  final baseTextTheme =
      night ? GoogleFonts.interTextTheme(base.textTheme) : base.textTheme;

  return ThemeData(
    brightness: night ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: colors.background,
    extensions: [colors],
    cardTheme: CardTheme(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: night ? _cyberBackground : colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(night ? 8 : 14),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceAlt,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.accent),
      ),
      labelStyle: TextStyle(color: colors.textMuted),
      hintStyle: TextStyle(color: colors.textSubtle),
      prefixIconColor: colors.textMuted,
    ),
    textTheme: baseTextTheme.apply(
      bodyColor: colors.text,
      displayColor: colors.text,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.surfaceSoft,
      selectedColor: colors.accent.withOpacity(night ? 0.2 : 0.14),
      side: BorderSide(color: colors.border),
      labelStyle: TextStyle(color: colors.text),
      secondaryLabelStyle: TextStyle(color: colors.text),
    ),
    dividerColor: colors.border,
  );
}

bool _isNightAppearance(String code) => code != 'day';

AuraThemeColors _aura(BuildContext context) {
  return Theme.of(context).extension<AuraThemeColors>() ??
      AuraThemeColors.night;
}

class AuraThemeColors extends ThemeExtension<AuraThemeColors> {
  const AuraThemeColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.surfaceSoft,
    required this.accent,
    required this.violet,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.border,
  });

  static const night = AuraThemeColors(
    background: _cyberBackground,
    surface: _cyberSurface,
    surfaceAlt: _cyberSurfaceAlt,
    surfaceSoft: _cyberSurfaceSoft,
    accent: _cyberAccent,
    violet: _cyberViolet,
    text: _cyberText,
    textMuted: _cyberTextMuted,
    textSubtle: _cyberTextSubtle,
    border: _cyberBorder,
  );

  static const day = AuraThemeColors(
    background: _dayBackground,
    surface: _daySurface,
    surfaceAlt: _daySurfaceAlt,
    surfaceSoft: _daySurfaceSoft,
    accent: _dayAccent,
    violet: _dayViolet,
    text: _dayText,
    textMuted: _dayTextMuted,
    textSubtle: _dayTextSubtle,
    border: _dayBorder,
  );

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color surfaceSoft;
  final Color accent;
  final Color violet;
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color border;

  @override
  AuraThemeColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? surfaceSoft,
    Color? accent,
    Color? violet,
    Color? text,
    Color? textMuted,
    Color? textSubtle,
    Color? border,
  }) {
    return AuraThemeColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      accent: accent ?? this.accent,
      violet: violet ?? this.violet,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textSubtle: textSubtle ?? this.textSubtle,
      border: border ?? this.border,
    );
  }

  @override
  AuraThemeColors lerp(ThemeExtension<AuraThemeColors>? other, double t) {
    if (other is! AuraThemeColors) {
      return this;
    }
    return AuraThemeColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      violet: Color.lerp(violet, other.violet, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSubtle: Color.lerp(textSubtle, other.textSubtle, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}

class LanguageScope extends InheritedWidget {
  const LanguageScope({
    super.key,
    required this.languageCode,
    required super.child,
  });

  final String languageCode;

  static String of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<LanguageScope>()
            ?.languageCode ??
        'zh_TW';
  }

  @override
  bool updateShouldNotify(LanguageScope oldWidget) {
    return oldWidget.languageCode != languageCode;
  }
}

String _t(BuildContext context, String zhTw, String en) {
  return LanguageScope.of(context) == 'en' ? en : zhTw;
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
    Widget consoleWidget() => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          child: _OutputConsole(
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
              color: _isNightAppearance(_appearanceThemeCode)
                  ? _cyberBackground
                  : _dayBackground,
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
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: _aura(context).text,
                          ),
                        ),
                        SelectableText(
                          branchPath,
                          style: GoogleFonts.jetBrainsMono(
                            color: _aura(context).textMuted,
                            fontSize: 12,
                            height: 1.35,
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
            color: Theme.of(context).brightness == Brightness.dark
                ? _stitchSurfaceDim
                : null,
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
                Builder(
                  builder: (context) {
                    final dark = Theme.of(context).brightness == Brightness.dark;
                    final aura = _aura(context);
                    final list = commits.isEmpty
                        ? Center(
                            child: Text(
                              _t(
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
                            itemBuilder: (context, index) =>
                                _CommitTimelineItem(
                              commit: commits[index],
                              isFirst: index == 0,
                              isLast: index == commits.length - 1,
                              repository: _selectedRepository,
                              settings: _settings,
                            ),
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
                        color: _stitchSurfaceDim,
                        border: Border(
                          right: BorderSide(
                            color: aura.border.withOpacity(0.22),
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
                                    _t(context, 'Commit 歷史', 'Commit History'),
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: aura.text,
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.filter_list_rounded,
                                      size: 16,
                                      color: aura.textSubtle,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'FILTER',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11,
                                        letterSpacing: 0.6,
                                        fontWeight: FontWeight.w500,
                                        color: aura.textSubtle,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 1,
                            color: aura.border.withOpacity(0.1),
                          ),
                          Expanded(child: list),
                        ],
                      ),
                    );
                  },
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

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.selectedRepository,
    required this.repositories,
    required this.isRefreshing,
    required this.status,
    required this.rootPath,
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.onRepositorySelected,
    required this.onUpdatePressed,
    required this.onRepositoryProfilesPressed,
    required this.onSettingsPressed,
  });

  final SvnRepository selectedRepository;
  final List<SvnRepository> repositories;
  final bool isRefreshing;
  final String status;
  final String rootPath;
  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final ValueChanged<SvnRepository> onRepositorySelected;
  final VoidCallback onUpdatePressed;
  final VoidCallback onRepositoryProfilesPressed;
  final VoidCallback onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aura = _aura(context);
    final isDark = theme.brightness == Brightness.dark;

    final sidebarDecoration = BoxDecoration(
      color: isDark ? _stitchSurfaceContainerHigh : aura.surfaceAlt,
      border: Border(
        right: BorderSide(
          color: aura.border.withOpacity(isDark ? 0.22 : 0.4),
        ),
      ),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 28,
                offset: const Offset(4, 0),
              ),
            ]
          : null,
    );

    final sidebarActionGray = isDark
        ? const Color(0xFFC8D0D0)
        : aura.textMuted;
    final sidebarActionStyle = TextButton.styleFrom(
      alignment: AlignmentDirectional.centerStart,
      foregroundColor: sidebarActionGray,
      backgroundColor: Colors.transparent,
      disabledForegroundColor: sidebarActionGray.withOpacity(0.45),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      minimumSize: const Size.fromHeight(44),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide.none,
      ),
    );

    if (collapsed) {
      return Container(
        decoration: sidebarDecoration,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            IconButton(
              tooltip: _t(context, '展開側邊控制欄', 'Expand side panel'),
              onPressed: onToggleCollapsed,
              icon: const Icon(Icons.keyboard_double_arrow_right_rounded),
            ),
            const SizedBox(height: 4),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: aura.border.withOpacity(0.4),
            ),
            const SizedBox(height: 14),
            Tooltip(
              message: selectedRepository.name,
              child: CircleAvatar(
                backgroundColor:
                    theme.colorScheme.primary.withOpacity(0.14),
                child: Text(
                  selectedRepository.name.replaceAll('_AP', '').substring(2),
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            IconButton(
              tooltip: _t(context, '執行增量更新', 'Run incremental update'),
              onPressed: isRefreshing ? null : onUpdatePressed,
              icon: isRefreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
            ),
            IconButton(
              tooltip: 'Repository Profiles',
              onPressed: isRefreshing ? null : onRepositoryProfilesPressed,
              icon: const Icon(Icons.storage_rounded),
            ),
            IconButton(
              tooltip: _t(context, '設定', 'Settings'),
              onPressed: isRefreshing ? null : onSettingsPressed,
              icon: const Icon(Icons.settings_rounded),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: sidebarDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 84,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(child: _AuraBrandMark()),
                  IconButton(
                    tooltip: _t(context, '收合側邊控制欄', 'Collapse side panel'),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    onPressed: onToggleCollapsed,
                    icon: const Icon(
                      Icons.keyboard_double_arrow_left_rounded,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 1,
            color: aura.border.withOpacity(0.35),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text(
                    'REPOSITORIES',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: aura.textSubtle,
                      height: 1.2,
                    ),
                  ),
                ),
                _RepositorySelector(
                  selectedRepository: selectedRepository,
                  repositories: repositories,
                  enabled: !isRefreshing,
                  onRepositorySelected: onRepositorySelected,
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _InfoLine(label: 'URL', value: selectedRepository.url),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _InfoLine(
                    label: _t(context, '專案根目錄', 'Project Root'),
                    value: rootPath,
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    height: 1,
                    color: aura.border.withOpacity(isDark ? 0.28 : 0.38),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed:
                        isRefreshing ? null : onRepositoryProfilesPressed,
                    icon: const Icon(Icons.storage_rounded),
                    label: const Text('Repository Profiles'),
                    style: sidebarActionStyle,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: isRefreshing ? null : onUpdatePressed,
                    icon: isRefreshing
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: sidebarActionGray,
                            ),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(
                      isRefreshing
                          ? _t(context, '更新中...', 'Updating...')
                          : _t(context, '執行增量更新', 'Run Incremental Update'),
                    ),
                    style: sidebarActionStyle,
                  ),
                ),
                const SizedBox(height: 10),
                _StatusPill(text: status, active: isRefreshing),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: isRefreshing ? null : onSettingsPressed,
                    icon: const Icon(Icons.settings_rounded),
                    label: Text(_t(context, '設定', 'Settings')),
                    style: sidebarActionStyle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RepositorySelector extends StatefulWidget {
  const _RepositorySelector({
    required this.selectedRepository,
    required this.repositories,
    required this.enabled,
    required this.onRepositorySelected,
  });

  final SvnRepository selectedRepository;
  final List<SvnRepository> repositories;
  final bool enabled;
  final ValueChanged<SvnRepository> onRepositorySelected;

  @override
  State<_RepositorySelector> createState() => _RepositorySelectorState();
}

class _RepositorySelectorState extends State<_RepositorySelector> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final repository in widget.repositories)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _RepositoryTile(
              repository: repository,
              selected: repository == widget.selectedRepository,
              enabled: widget.enabled,
              onTap: () {
                if (repository == widget.selectedRepository) {
                  return;
                }
                widget.onRepositorySelected(repository);
              },
            ),
          ),
      ],
    );
  }
}

class _AuraBrandMark extends StatelessWidget {
  const _AuraBrandMark();

  @override
  Widget build(BuildContext context) {
    final aura = _aura(context);
    return Align(
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Aura ',
                      style: GoogleFonts.inter(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? _stitchPrimaryFixed
                            : aura.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        height: 1,
                      ),
                    ),
                    TextSpan(
                      text: 'SVN',
                      style: GoogleFonts.inter(
                        color: aura.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Insightful SVN Client',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: aura.textMuted,
                  height: 1,
                  fontSize: 13,
                  letterSpacing: 0.15,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutputConsole extends StatelessWidget {
  const _OutputConsole({
    required this.logs,
    required this.expanded,
    required this.onToggleExpanded,
  });

  final List<String> logs;
  final bool expanded;
  final VoidCallback onToggleExpanded;

  @override
  Widget build(BuildContext context) {
    const collapsedHeight = 64.0;
    const headerHeight = 54.0;
    final latestLine = logs.isEmpty
        ? _t(
            context,
            '尚無執行紀錄。按下「執行增量更新」後，SVN loader 輸出會顯示在這裡。',
            'No run logs yet. After running an incremental update, SVN loader output will appear here.',
          )
        : logs.last;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      height: expanded ? 260 : collapsedHeight,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0D1515),
        border: Border(
          top: BorderSide(color: Color(0xFF334155)),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
              height: headerHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.terminal_rounded,
                      color: Color(0xFF93C5FD),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Output Console',
                      style: TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        latestLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _t(context, '複製全部', 'Copy All'),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                      onPressed: logs.isEmpty
                          ? null
                          : () {
                              Clipboard.setData(
                                ClipboardData(text: logs.join('\n')),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(_t(
                                    context,
                                    '已複製全部執行紀錄',
                                    'Copied all run logs',
                                  )),
                                ),
                              );
                            },
                      icon: const Icon(Icons.copy_rounded),
                      color: const Color(0xFFE2E8F0),
                    ),
                    IconButton(
                      tooltip: expanded
                          ? _t(context, '收合 Console', 'Collapse Console')
                          : _t(context, '展開 Console', 'Expand Console'),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 40,
                        height: 40,
                      ),
                      onPressed: onToggleExpanded,
                      icon: Icon(
                        expanded
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_up_rounded,
                      ),
                      color: const Color(0xFFE2E8F0),
                    ),
                  ],
                ),
              ),
            ),
            if (expanded)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0xFF1E293B)),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: logs.isEmpty
                      ? Text(
                          latestLine,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        )
                      : SelectionArea(
                          child: ListView.builder(
                            itemCount: logs.length,
                            itemBuilder: (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                logs[index],
                                style: const TextStyle(
                                  color: Color(0xFFE2E8F0),
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
          ],
        ),
    );
  }
}

class _BranchCommitPreviewDialog extends StatelessWidget {
  const _BranchCommitPreviewDialog({
    required this.branchPath,
    required this.commits,
  });

  final String branchPath;
  final List<CommitRecord> commits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.all(28),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: _aura(context).surface.withOpacity(0.72),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.34),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withOpacity(0.14),
                  blurRadius: 34,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.38),
                  blurRadius: 40,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 920,
                maxHeight: size.height * 0.82,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              theme.colorScheme.primary.withOpacity(0.14),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t(context, 'Branch Commit 預覽',
                                    'Branch Commit Preview'),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SelectableText(
                                branchPath,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _aura(context).textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Chip(
                          avatar:
                              const Icon(Icons.receipt_long_rounded, size: 18),
                          label: Text('${commits.length} commits'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
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
                              itemBuilder: (context, index) {
                                final commit = commits[index];
                                return _BranchCommitPreviewTile(commit: commit);
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(_t(context, '關閉', 'Close')),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).pop(true),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: Text(_t(context, '詳情', 'Details')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BranchCommitPreviewTile extends StatelessWidget {
  const _BranchCommitPreviewTile({required this.commit});

  final CommitRecord commit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = commit.message.trim().isEmpty
        ? _t(context, '(無 commit message)', '(No commit message)')
        : commit.message.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _aura(context).surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _aura(context).border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _RevisionText(revision: commit.revision),
                    if (commit.author.isNotEmpty)
                      _MiniMetaChip(
                        icon: Icons.person_outline_rounded,
                        label: commit.author,
                      ),
                    if (commit.date.isNotEmpty)
                      _MiniMetaChip(
                        icon: Icons.schedule_rounded,
                        label: _shortCommitDate(commit.date),
                      ),
                    _MiniMetaChip(
                      icon: Icons.edit_rounded,
                      label: '${commit.changedPaths.length} paths',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _aura(context).textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RevisionText extends StatelessWidget {
  const _RevisionText({required this.revision});

  final int revision;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      revision.toString(),
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _MiniMetaChip extends StatelessWidget {
  const _MiniMetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _aura(context).surfaceSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _aura(context).border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _aura(context).textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _aura(context).textMuted,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

String _shortCommitDate(String date) {
  if (date.length >= 10) {
    return date.substring(0, 10);
  }
  return date;
}

/// 頂部區與主內容之間：細青色邊線 + 向下漸層漏光（對齊 Stitch 類 HTML 效果）。
class _DataPanelTopLeakDivider extends StatelessWidget {
  const _DataPanelTopLeakDivider();

  /// 漸層向下延伸，拉長羽化；整體亮度靠低 alpha 壓低。
  static const double _glowExtent = 64;

  @override
  Widget build(BuildContext context) {
    final line = Color.alphaBlend(
      _cyberAccent.withOpacity(0.11),
      _cyberBackground,
    );
    return SizedBox(
      height: 1 + _glowExtent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 1, color: line),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.2, 0.42, 0.65, 0.86, 1.0],
                  colors: [
                    Color.alphaBlend(
                      _cyberAccent.withOpacity(0.038),
                      _cyberBackground,
                    ),
                    Color.alphaBlend(
                      _cyberAccent.withOpacity(0.022),
                      _cyberBackground,
                    ),
                    Color.alphaBlend(
                      _cyberAccent.withOpacity(0.012),
                      _cyberBackground,
                    ),
                    Color.alphaBlend(
                      _cyberAccent.withOpacity(0.006),
                      _cyberBackground,
                    ),
                    Color.alphaBlend(
                      _cyberAccent.withOpacity(0.002),
                      _cyberBackground,
                    ),
                    _cyberBackground,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataPanel extends StatelessWidget {
  const _DataPanel({
    required this.repository,
    required this.data,
    required this.error,
    required this.isCompact,
    required this.showVisualMap,
    required this.settings,
    required this.backendStatus,
    required this.onCheckBackend,
    required this.onStartBackend,
    required this.onVisualMapChanged,
    required this.onAiAnalysisPressed,
    required this.onAiHistoryPressed,
    required this.onBranchSelected,
  });

  final SvnRepository repository;
  final AppData data;
  final String? error;
  final bool isCompact;
  final bool showVisualMap;
  final AppSettings settings;
  final String backendStatus;
  final Future<void> Function() onCheckBackend;
  final Future<void> Function() onStartBackend;
  final ValueChanged<bool> onVisualMapChanged;
  final VoidCallback onAiAnalysisPressed;
  final VoidCallback onAiHistoryPressed;
  final ValueChanged<String> onBranchSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latest = data.latestCommit;
    final isDark = theme.brightness == Brightness.dark;
    final aura = _aura(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        isDark
            ? DecoratedBox(
                decoration: const BoxDecoration(
                  color: Color(0xFF0D1515),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  repository.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                    color: _stitchPrimaryFixed,
                                  ),
                                ),
                                Text(
                                  repository.url,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: aura.textMuted,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (latest != null)
                                Chip(
                                  avatar: const Icon(Icons.history_rounded,
                                      size: 18),
                                  label:
                                      Text('Latest r${latest.revision}'),
                                ),
                              FilledButton.icon(
                                onPressed: onAiAnalysisPressed,
                                icon: const Icon(Icons.auto_awesome_rounded),
                                label: Text(_t(context, 'AI 專案分析',
                                    'AI Project Analysis')),
                              ),
                              OutlinedButton.icon(
                                onPressed: onAiHistoryPressed,
                                icon: const Icon(Icons.history_edu_rounded),
                                label: Text(_t(
                                  context,
                                  '瀏覽歷史AI分析',
                                  'Browse AI Analysis History',
                                )),
                              ),
                              SegmentedButton<bool>(
                                style: ButtonStyle(
                                  backgroundColor:
                                      MaterialStateProperty.resolveWith(
                                          (states) {
                                    if (states.contains(
                                            MaterialState.selected) &&
                                        Theme.of(context).brightness ==
                                            Brightness.dark) {
                                      return const Color(0xFF17233F);
                                    }
                                    return null;
                                  }),
                                ),
                                segments: const [
                                  ButtonSegment(
                                    value: false,
                                    icon: Icon(Icons.account_tree_outlined),
                                    label: Text('Topology'),
                                  ),
                                  ButtonSegment(
                                    value: true,
                                    icon: Icon(Icons.hub_rounded),
                                    label: Text('Visual Map'),
                                  ),
                                ],
                                selected: {showVisualMap},
                                onSelectionChanged: (selection) {
                                  onVisualMapChanged(selection.first);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 16),
                        _ErrorBanner(error: error!),
                      ],
                      const SizedBox(height: 22),
                      LayoutBuilder(
                        builder: (context, c) {
                          const gap = 10.0;
                          final inner = c.maxWidth.isFinite && c.maxWidth > 0
                              ? c.maxWidth
                              : (MediaQuery.sizeOf(context).width - 96)
                                  .clamp(240.0, 2400.0);
                          final cardW = inner > 3 * gap
                              ? (inner - 3 * gap) / 4
                              : inner / 4;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: cardW,
                                child: _MetricCard(
                                  label: _t(context, 'Commits', 'Commits'),
                                  value: data.commits.length.toString(),
                                  icon: Icons.receipt_long_rounded,
                                  accentBorder: _metricStripLeftCommits,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: cardW,
                                child: _MetricCard(
                                  label: _t(context, '節點', 'Nodes'),
                                  value: data.topology.length.toString(),
                                  icon: Icons.account_tree_outlined,
                                  accentBorder: _metricStripLeftNodes,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: cardW,
                                child: _BackendStatusCard(
                                  status: backendStatus,
                                  onCheck: onCheckBackend,
                                  onStart: onStartBackend,
                                  accentBorder: _metricStripLeftBackend,
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: cardW,
                                child: _MetricCard(
                                  label: _t(context, '作者', 'Author'),
                                  value: latest?.author.isNotEmpty == true
                                      ? latest!.author
                                      : '-',
                                  icon: Icons.person_search_rounded,
                                  accentBorder: _metricStripLeftAuthor,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              )
              : Material(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    repository.name,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    repository.url,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                      color: _aura(context).textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (latest != null)
                                  Chip(
                                    avatar: const Icon(Icons.history_rounded,
                                        size: 18),
                                    label: Text('Latest r${latest.revision}'),
                                  ),
                                FilledButton.icon(
                                  onPressed: onAiAnalysisPressed,
                                  icon: const Icon(Icons.auto_awesome_rounded),
                                  label: Text(_t(context, 'AI 專案分析',
                                      'AI Project Analysis')),
                                ),
                                OutlinedButton.icon(
                                  onPressed: onAiHistoryPressed,
                                  icon: const Icon(Icons.history_edu_rounded),
                                  label: Text(_t(
                                    context,
                                    '瀏覽歷史AI分析',
                                    'Browse AI Analysis History',
                                  )),
                                ),
                                SegmentedButton<bool>(
                                  style: ButtonStyle(
                                    backgroundColor:
                                        MaterialStateProperty.resolveWith(
                                            (states) {
                                      if (states.contains(
                                              MaterialState.selected) &&
                                          Theme.of(context).brightness ==
                                              Brightness.dark) {
                                        return const Color(0xFF17233F);
                                      }
                                      return null;
                                    }),
                                  ),
                                  segments: const [
                                    ButtonSegment(
                                      value: false,
                                      icon: Icon(Icons.account_tree_outlined),
                                      label: Text('Topology'),
                                    ),
                                    ButtonSegment(
                                      value: true,
                                      icon: Icon(Icons.hub_rounded),
                                      label: Text('Visual Map'),
                                    ),
                                  ],
                                  selected: {showVisualMap},
                                  onSelectionChanged: (selection) {
                                    onVisualMapChanged(selection.first);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 16),
                          _ErrorBanner(error: error!),
                        ],
                        const SizedBox(height: 22),
                        LayoutBuilder(
                          builder: (context, c) {
                            const gap = 10.0;
                            final inner = c.maxWidth.isFinite && c.maxWidth > 0
                                ? c.maxWidth
                                : (MediaQuery.sizeOf(context).width - 96)
                                    .clamp(240.0, 2400.0);
                            final cardW = inner > 3 * gap
                                ? (inner - 3 * gap) / 4
                                : inner / 4;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: cardW,
                                  child: _MetricCard(
                                    label: _t(context, 'Commits', 'Commits'),
                                    value: data.commits.length.toString(),
                                    icon: Icons.receipt_long_rounded,
                                    accentBorder: _metricStripLeftCommits,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: cardW,
                                  child: _MetricCard(
                                    label: _t(context, '節點', 'Nodes'),
                                    value: data.topology.length.toString(),
                                    icon: Icons.account_tree_outlined,
                                    accentBorder: _metricStripLeftNodes,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: cardW,
                                  child: _BackendStatusCard(
                                    status: backendStatus,
                                    onCheck: onCheckBackend,
                                    onStart: onStartBackend,
                                    accentBorder: _metricStripLeftBackend,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: cardW,
                                  child: _MetricCard(
                                    label: _t(context, '作者', 'Author'),
                                    value: latest?.author.isNotEmpty == true
                                        ? latest!.author
                                        : '-',
                                    icon: Icons.person_search_rounded,
                                    accentBorder: _metricStripLeftAuthor,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                ),
        if (isDark) const _DataPanelTopLeakDivider(),
        Expanded(
          child: data.isEmpty
              ? const _EmptyDataCard()
              : showVisualMap
                  ? BranchMapView(
                      repository: repository,
                      data: data,
                      settings: settings,
                      onBranchSelected: onBranchSelected,
                    )
                  : _TopologyCard(
                      data: data,
                      onBranchSelected: onBranchSelected,
                    ),
        ),
      ],
    );
  }
}

class _TopologyCard extends StatelessWidget {
  const _TopologyCard({
    required this.data,
    required this.onBranchSelected,
  });

  final AppData data;
  final ValueChanged<String> onBranchSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nodes = data.topology.entries.toList()
      ..sort((a, b) {
        final aTrunk = _isTrunkPath(a.key);
        final bTrunk = _isTrunkPath(b.key);
        if (aTrunk != bTrunk) {
          return aTrunk ? -1 : 1;
        }
        return a.key.compareTo(b.key);
      });

    final panelBg = theme.brightness == Brightness.dark
        ? _cyberBackground
        : _aura(context).surfaceAlt;

    return Material(
      color: panelBg,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Topology',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _t(
                context,
                '以父子關係呈現分支與標籤建立來源',
                'Shows branch and tag origins by parent-child relationship',
              ),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: _aura(context).textMuted),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: nodes.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final entry = nodes[index];
                  return _TopologyNodeTile(
                    path: entry.key,
                    node: entry.value,
                    selected: false,
                    onTap: () => onBranchSelected(entry.key),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RepositoryTile extends StatelessWidget {
  const _RepositoryTile({
    required this.repository,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final SvnRepository repository;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aura = _aura(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = aura.violet;
    final selectedFg =
        isDark ? const Color(0xFFF8D8FF) : aura.accent;
    final unselectedLabel = aura.textMuted;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      transform: selected && isDark
          ? (Matrix4.identity()..translate(4, 0, 0))
          : Matrix4.identity(),
      decoration: BoxDecoration(
        color: selected
            ? accentColor.withOpacity(0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(isDark ? 8 : 10),
        border: selected
            ? Border(
                left: BorderSide(
                  color: accentColor,
                  width: isDark ? 4 : 3,
                ),
              )
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(isDark ? 8 : 10),
          hoverColor: isDark
              ? aura.accent.withOpacity(0.05)
              : aura.surfaceSoft.withOpacity(0.4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            child: Row(
              children: [
                Icon(
                  Icons.account_tree_rounded,
                  size: 20,
                  color: selected ? selectedFg : unselectedLabel,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        repository.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                          color: selected ? selectedFg : aura.text,
                          height: 1.25,
                        ),
                      ),
                      if (repository.subtitle.isNotEmpty ||
                          repository.url.isNotEmpty)
                        Text(
                          repository.subtitle.isNotEmpty
                              ? repository.subtitle
                              : repository.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: unselectedLabel,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1.2,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopologyNodeTile extends StatelessWidget {
  const _TopologyNodeTile({
    required this.path,
    required this.node,
    required this.selected,
    required this.onTap,
  });

  final String path;
  final BranchNode node;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final children = node.children;
    const radius = 0.0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: selected
                ? theme.colorScheme.primary.withOpacity(0.08)
                : (isDark ? _stitchGlassFill : _aura(context).surfaceAlt),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary.withOpacity(0.35)
                  : (isDark ? _stitchGlassBorder : _aura(context).border),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    node.kind == 'tag'
                        ? Icons.sell_outlined
                        : Icons.call_split_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      path,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SmallChip(label: 'kind', value: node.kind ?? 'root'),
                  _SmallChip(
                      label: 'origin_rev',
                      value: node.originRev?.toString() ?? '-'),
                  _SmallChip(
                      label: 'parent_rev',
                      value: node.parentRev?.toString() ?? '-'),
                  _SmallChip(
                      label: 'children', value: children.length.toString()),
                ],
              ),
              if (node.parent != null) ...[
                const SizedBox(height: 10),
                _InfoLine(label: 'parent', value: node.parent!),
              ],
              if (children.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'children',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: _aura(context).textMuted),
                ),
                const SizedBox(height: 4),
                ...children.map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.subdirectory_arrow_right_rounded,
                            size: 16),
                        const SizedBox(width: 6),
                        Expanded(child: Text(child)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CommitTimelineItem extends StatelessWidget {
  const _CommitTimelineItem({
    required this.commit,
    required this.isFirst,
    required this.isLast,
    this.repository,
    this.settings,
  });

  final CommitRecord commit;
  final bool isFirst;
  final bool isLast;
  final SvnRepository? repository;
  final AppSettings? settings;

  @override
  Widget build(BuildContext context) {
    final aura = _aura(context);
    final highlight = isFirst;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 22,
              child: CustomPaint(
                painter: _TimelineRailPainter(
                  lineColor: aura.border,
                  nodeColor: highlight ? _stitchPrimaryFixed : aura.border,
                  nodeGlowColor: highlight
                      ? _stitchPrimaryFixed.withOpacity(0.85)
                      : aura.border.withOpacity(0.5),
                  isFirst: isFirst,
                  isLast: isLast,
                  highlightNode: highlight,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: _CommitTile(
                  commit: commit,
                  repository: repository,
                  settings: settings,
                  highlighted: highlight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineRailPainter extends CustomPainter {
  _TimelineRailPainter({
    required this.lineColor,
    required this.nodeColor,
    required this.nodeGlowColor,
    required this.isFirst,
    required this.isLast,
    required this.highlightNode,
  });

  final Color lineColor;
  final Color nodeColor;
  final Color nodeGlowColor;
  final bool isFirst;
  final bool isLast;
  final bool highlightNode;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width * 0.45;
    const nodeY = 22.0;

    final linePaint = Paint()
      ..color = lineColor.withOpacity(0.35)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    if (!isFirst) {
      canvas.drawLine(
        Offset(centerX, 0),
        Offset(centerX, nodeY - 5),
        linePaint,
      );
    }
    if (!isLast) {
      canvas.drawLine(
        Offset(centerX, nodeY + 5),
        Offset(centerX, size.height),
        linePaint,
      );
    }

    if (highlightNode) {
      final glowPaint = Paint()
        ..color = nodeGlowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(centerX, nodeY), 5, glowPaint);
    }

    final nodePaint = Paint()..color = nodeColor;
    canvas.drawCircle(Offset(centerX, nodeY), highlightNode ? 4 : 3.5, nodePaint);
  }

  @override
  bool shouldRepaint(covariant _TimelineRailPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.nodeColor != nodeColor ||
        oldDelegate.nodeGlowColor != nodeGlowColor ||
        oldDelegate.isFirst != isFirst ||
        oldDelegate.isLast != isLast ||
        oldDelegate.highlightNode != highlightNode;
  }
}

class _CommitTile extends StatefulWidget {
  const _CommitTile({
    required this.commit,
    this.repository,
    this.settings,
    this.highlighted = false,
  });

  final CommitRecord commit;
  final SvnRepository? repository;
  final AppSettings? settings;
  final bool highlighted;

  @override
  State<_CommitTile> createState() => _CommitTileState();
}

class _CommitTileState extends State<_CommitTile> {
  String? _loadingDiffPath;
  final _diffErrors = <String, String>{};

  Future<void> _loadDiff(ChangedPath changedPath,
      {bool refresh = false}) async {
    final repository = widget.repository;
    final settings = widget.settings;
    if (repository == null || settings == null) {
      return;
    }

    setState(() {
      _loadingDiffPath = changedPath.path;
      _diffErrors.remove(changedPath.path);
    });

    try {
      final result = await _loadRevisionDiff(
        settings: settings,
        repository: repository,
        revision: widget.commit.revision,
        path: changedPath.path,
        refresh: refresh,
      );
      if (!mounted) {
        return;
      }
      final languageCode = LanguageScope.of(context);
      await showDialog<void>(
        context: context,
        builder: (context) => LanguageScope(
          languageCode: languageCode,
          child: _RevisionDiffDialog(result: result),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _diffErrors[changedPath.path] = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          if (_loadingDiffPath == changedPath.path) {
            _loadingDiffPath = null;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aura = _aura(context);
    final commit = widget.commit;
    final isDark = theme.brightness == Brightness.dark;
    final hl = widget.highlighted;

    return Theme(
      data: theme.copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isDark ? 0 : 10),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark ? _stitchGlassFill : aura.surface,
                borderRadius: BorderRadius.circular(isDark ? 0 : 10),
                border: Border(
                  left: BorderSide(
                    width: hl ? 2 : 1,
                    color: hl
                        ? _stitchPrimaryFixed
                        : (isDark
                            ? _stitchGlassBorder
                            : aura.border.withOpacity(0.65)),
                  ),
                  top: BorderSide(
                    color: isDark
                        ? _stitchGlassBorder
                        : aura.border.withOpacity(0.4),
                  ),
                  right: BorderSide(
                    color: isDark
                        ? _stitchGlassBorder
                        : aura.border.withOpacity(0.4),
                  ),
                  bottom: BorderSide(
                    color: isDark
                        ? _stitchGlassBorder
                        : aura.border.withOpacity(0.4),
                  ),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
      tilePadding: const EdgeInsets.fromLTRB(14, 6, 12, 6),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      collapsedShape: const RoundedRectangleBorder(),
      shape: const RoundedRectangleBorder(),
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      iconColor: aura.textMuted,
      collapsedIconColor: aura.textMuted,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'r${commit.revision}',
                style: GoogleFonts.jetBrainsMono(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: hl ? _stitchPrimaryFixed : aura.textMuted,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Text(
                _shortCommitDate(commit.date),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  letterSpacing: 0.55,
                  color: aura.textSubtle,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            commit.message.isEmpty ? '(no message)' : commit.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: aura.text,
              height: 1.35,
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: aura.surfaceSoft,
                border: Border.all(
                  color: aura.border.withOpacity(0.6),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                commit.author.isEmpty
                    ? '?'
                    : commit.author.substring(0, 1).toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: aura.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                commit.author.isEmpty ? 'unknown' : commit.author,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.4,
                  color: aura.textSubtle,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (commit.ticketId.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: aura.violet.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  commit.ticketId,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: aura.violet,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: aura.surfaceSoft,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: aura.border.withOpacity(0.5),
                ),
              ),
              child: Text(
                '${commit.changedPaths.length} paths',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: aura.textMuted,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
      children: [
        _InfoLine(label: 'date', value: commit.date),
        const SizedBox(height: 10),
        Text(
          _t(
            context,
            '點選檔案名稱即可即時抓取並顯示該檔案 Diff。',
            'Click a file name to fetch and show only that file diff.',
          ),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: _aura(context).textMuted),
        ),
        const SizedBox(height: 10),
        ...commit.changedPaths.take(30).map(
          (path) {
            final isLoading = _loadingDiffPath == path.path;
            final error = _diffErrors[path.path];
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: _actionColor(path.action).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          path.action,
                          style: TextStyle(
                            color: _actionColor(path.action),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: widget.repository == null ||
                                  widget.settings == null ||
                                  _loadingDiffPath != null
                              ? null
                              : () => _loadDiff(path),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              path.copyFromPath == null
                                  ? path.path
                                  : '${path.path}  <-  ${path.copyFromPath}@${path.copyFromRev ?? '-'}',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isLoading) ...[
                        const SizedBox(width: 8),
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ] else ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: _t(context, '重新抓取 Diff', 'Refresh Diff'),
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          onPressed: widget.repository == null ||
                                  widget.settings == null ||
                                  _loadingDiffPath != null
                              ? null
                              : () => _loadDiff(path, refresh: true),
                        ),
                      ],
                    ],
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 4),
                    SelectableText(
                      error,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
        if (commit.changedPaths.length > 30)
          Text(_t(
            context,
            '另有 ${commit.changedPaths.length - 30} 筆路徑未展開',
            '${commit.changedPaths.length - 30} more paths are hidden',
          )),
      ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _RevisionDiffDialog extends StatelessWidget {
  const _RevisionDiffDialog({required this.result});

  final RevisionDiffResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final files = _parseUnifiedDiff(result.diff);
    return Dialog(
      insetPadding: const EdgeInsets.all(28),
      child: SizedBox(
        width: size.width * 0.9,
        height: size.height * 0.86,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        theme.colorScheme.primary.withOpacity(0.12),
                    child: Icon(
                      Icons.difference_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.path.isEmpty
                              ? '${result.repoName} r${result.revision} Diff'
                              : '${result.repoName} r${result.revision} ${_t(context, '檔案 Diff', 'File Diff')}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          result.cached
                              ? _t(
                                  context, '來源：本機 cache', 'Source: local cache')
                              : _t(
                                  context,
                                  '來源：SVN 即時抓取',
                                  'Source: fetched from SVN',
                                ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: result.diff));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(_t(context, '已複製 Diff', 'Diff copied')),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(_t(context, '複製 Diff', 'Copy Diff')),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: _t(context, '關閉', 'Close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (result.path.isNotEmpty) ...[
                _InfoLine(label: _t(context, '檔案', 'File'), value: result.path),
                const SizedBox(height: 8),
              ],
              _InfoLine(label: 'Cache', value: result.cacheFile),
              const SizedBox(height: 12),
              Expanded(child: _UnifiedDiffViewer(files: files)),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DiffLineKind { meta, hunk, context, added, removed }

class _DiffLine {
  const _DiffLine({
    required this.kind,
    required this.text,
    this.oldLine,
    this.newLine,
  });

  final _DiffLineKind kind;
  final String text;
  final int? oldLine;
  final int? newLine;
}

class _DiffFile {
  const _DiffFile({
    required this.path,
    required this.lines,
    required this.rawText,
    required this.additions,
    required this.deletions,
  });

  final String path;
  final List<_DiffLine> lines;
  final String rawText;
  final int additions;
  final int deletions;
}

// Retained for the previous Flutter-native diff viewer.
// ignore: unused_element
List<_DiffFile> _parseUnifiedDiff(String diff) {
  if (diff.trim().isEmpty) {
    return const [];
  }

  final sourceLines = diff.split(RegExp(r'\r?\n'));
  final files = <_DiffFile>[];
  var currentRaw = <String>[];
  var currentPath = 'Diff';

  void flush() {
    if (currentRaw.isEmpty) {
      return;
    }
    files.add(_buildDiffFile(currentPath, currentRaw));
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

_DiffFile _buildDiffFile(String fallbackPath, List<String> rawLines) {
  var path = fallbackPath;
  for (final line in rawLines) {
    if (line.startsWith('+++ ')) {
      final parsed = _cleanDiffPath(line.substring(4));
      if (parsed.isNotEmpty) {
        path = parsed;
      }
      break;
    }
  }

  final lines = <_DiffLine>[];
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
      lines.add(_DiffLine(kind: _DiffLineKind.hunk, text: raw));
      continue;
    }

    if (raw.startsWith('+') && !raw.startsWith('+++')) {
      lines.add(
        _DiffLine(kind: _DiffLineKind.added, text: raw, newLine: newLine),
      );
      newLine += 1;
      additions += 1;
      continue;
    }
    if (raw.startsWith('-') && !raw.startsWith('---')) {
      lines.add(
        _DiffLine(kind: _DiffLineKind.removed, text: raw, oldLine: oldLine),
      );
      oldLine += 1;
      deletions += 1;
      continue;
    }
    if (raw.startsWith(' ') || raw.isEmpty) {
      lines.add(_DiffLine(
        kind: _DiffLineKind.context,
        text: raw,
        oldLine: oldLine,
        newLine: newLine,
      ));
      oldLine += 1;
      newLine += 1;
      continue;
    }
    lines.add(_DiffLine(kind: _DiffLineKind.meta, text: raw));
  }

  return _DiffFile(
    path: path,
    lines: lines,
    rawText: rawLines.join('\n'),
    additions: additions,
    deletions: deletions,
  );
}

String _cleanDiffPath(String value) {
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

// Retained for the previous Flutter-native diff viewer.
// ignore: unused_element
class _UnifiedDiffViewer extends StatelessWidget {
  const _UnifiedDiffViewer({required this.files});

  final List<_DiffFile> files;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) {
      return const Center(child: Text('(empty diff)'));
    }

    return ListView.separated(
      itemCount: files.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _DiffFileCard(file: files[index]),
    );
  }
}

class _DiffFileCard extends StatelessWidget {
  const _DiffFileCard({required this.file});

  final _DiffFile file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: SelectableText(
          file.path,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text('+${file.additions} -${file.deletions}'),
        trailing: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _DiffStatPill(
              text: '+${file.additions}',
              color: Colors.green,
            ),
            _DiffStatPill(
              text: '-${file.deletions}',
              color: Colors.red,
            ),
            IconButton(
              tooltip: _t(context, '複製此檔案 Diff', 'Copy this file diff'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: file.rawText));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_t(
                      context,
                      '已複製此檔案 Diff',
                      'Copied this file diff',
                    )),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded),
            ),
          ],
        ),
        children: [
          const Divider(height: 1),
          _DiffLinesTable(lines: file.lines),
        ],
      ),
    );
  }
}

class _DiffStatPill extends StatelessWidget {
  const _DiffStatPill({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DiffLinesTable extends StatelessWidget {
  const _DiffLinesTable({required this.lines});

  final List<_DiffLine> lines;

  @override
  Widget build(BuildContext context) {
    final blocks = _buildDiffLineBlocks(lines);

    return SelectionArea(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              blocks.map((block) => _DiffLineBlockView(block: block)).toList(),
        ),
      ),
    );
  }
}

class _DiffLineBlock {
  const _DiffLineBlock({
    required this.lines,
    required this.oldStart,
    required this.oldEnd,
    required this.newStart,
    required this.newEnd,
  });

  final List<_DiffLine> lines;
  final int? oldStart;
  final int? oldEnd;
  final int? newStart;
  final int? newEnd;
}

List<_DiffLineBlock> _buildDiffLineBlocks(List<_DiffLine> lines) {
  final blocks = <_DiffLineBlock>[];
  var current = <_DiffLine>[];
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
    blocks.add(_DiffLineBlock(
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
    if (line.kind == _DiffLineKind.meta || line.kind == _DiffLineKind.hunk) {
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

class _DiffLineBlockView extends StatelessWidget {
  const _DiffLineBlockView({required this.block});

  final _DiffLineBlock block;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DiffLineRange(start: block.oldStart, end: block.oldEnd),
          _DiffLineRange(start: block.newStart, end: block.newEnd),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: block.lines
                .map((line) => _DiffLineContentRow(line: line))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _DiffLineContentRow extends StatelessWidget {
  const _DiffLineContentRow({required this.line});

  final _DiffLine line;

  @override
  Widget build(BuildContext context) {
    final background = switch (line.kind) {
      _DiffLineKind.added => const Color(0xFFE6FFEC),
      _DiffLineKind.removed => const Color(0xFFFFEBE9),
      _DiffLineKind.hunk => const Color(0xFFDDF4FF),
      _DiffLineKind.meta => const Color(0xFFF6F8FA),
      _DiffLineKind.context => Colors.white,
    };
    final textColor = switch (line.kind) {
      _DiffLineKind.added => const Color(0xFF116329),
      _DiffLineKind.removed => const Color(0xFF82071E),
      _DiffLineKind.hunk => const Color(0xFF0969DA),
      _DiffLineKind.meta => const Color(0xFF57606A),
      _DiffLineKind.context => const Color(0xFF24292F),
    };
    final marker = switch (line.kind) {
      _DiffLineKind.added => '+',
      _DiffLineKind.removed => '-',
      _DiffLineKind.hunk => '@',
      _ => ' ',
    };

    return Container(
      color: background,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              marker,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 900),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SelectableText(
                _displayDiffText(line.text),
                style: TextStyle(
                  color: textColor,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiffLineRange extends StatelessWidget {
  const _DiffLineRange({
    required this.start,
    required this.end,
  });

  final int? start;
  final int? end;

  @override
  Widget build(BuildContext context) {
    final text = start == null
        ? ''
        : start == end
            ? start.toString()
            : '$start-$end';

    return Container(
      width: 70,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      color: Colors.black.withOpacity(0.03),
      child: Text(
        text,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: Color(0xFF6E7781),
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.35,
        ),
      ),
    );
  }
}

String _displayDiffText(String text) {
  if (text.startsWith('+') || text.startsWith('-') || text.startsWith(' ')) {
    return text.length > 1 ? text.substring(1) : '';
  }
  return text;
}

BoxDecoration _dashboardStatStripDecoration(
  BuildContext context, {
  required Color accentBorder,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final edge = isDark ? _stitchGlassBorder : _aura(context).border;
  return BoxDecoration(
    color: isDark ? _stitchGlassFill : _aura(context).surfaceAlt,
    borderRadius: BorderRadius.circular(4),
    border: Border(
      left: BorderSide(color: accentBorder, width: 3),
      top: BorderSide(color: edge, width: 1),
      right: BorderSide(color: edge, width: 1),
      bottom: BorderSide(color: edge, width: 1),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentBorder,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentBorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aura = _aura(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: _dashboardStatStripDecoration(
        context,
        accentBorder: accentBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: ' · ',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: aura.textMuted),
                  ),
                  TextSpan(
                    text: label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: aura.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _BackendStatusCard extends StatelessWidget {
  const _BackendStatusCard({
    required this.status,
    required this.onCheck,
    required this.onStart,
    required this.accentBorder,
  });

  final String status;
  final Future<void> Function() onCheck;
  final Future<void> Function() onStart;
  final Color accentBorder;

  @override
  Widget build(BuildContext context) {
    final summary = _backendStatusSummary(status);
    final style = _backendStatusStyle(summary);
    final theme = Theme.of(context);
    final aura = _aura(context);
    final backendLabel = _t(context, '後端', 'Backend');

    return PopupMenuButton<String>(
      tooltip: status,
      onSelected: (value) {
        if (value == 'check') {
          onCheck();
        } else if (value == 'start') {
          onStart();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'check',
          child: Text(_t(context, '重新檢查連線', 'Recheck Connection')),
        ),
        PopupMenuItem(
          value: 'start',
          child: Text(_t(context, '啟動本地後端', 'Start Local Backend')),
        ),
      ],
      child: Tooltip(
        message:
            '$status\n\n${_t(context, '點擊可重新檢查或啟動本地後端。', 'Click to recheck or start the local backend.')}',
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: _dashboardStatStripDecoration(
              context,
              accentBorder: accentBorder,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(style.icon, color: style.color, size: 19),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: _localizedBackendSummary(context, summary),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: style.color,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        TextSpan(
                          text: ' · ',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: aura.textMuted),
                        ),
                        TextSpan(
                          text: backendLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: aura.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _aura(context).surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _aura(context).border),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
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

String _localizedBackendSummary(BuildContext context, String summary) {
  switch (summary) {
    case '已連線':
      return _t(context, '已連線', 'Connected');
    case '檢查中':
      return _t(context, '檢查中', 'Checking');
    case '異常':
      return _t(context, '異常', 'Error');
    case '未連線':
      return _t(context, '未連線', 'Offline');
    default:
      return _t(context, '未確認', 'Unknown');
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 86,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: _aura(context).textSubtle,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.active});

  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final MaterialColor color = active ? Colors.blue : Colors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            active
                ? Icons.hourglass_top_rounded
                : Icons.check_circle_outline_rounded,
            size: 18,
            color: color.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _localizedRuntimeText(context, text),
              style: TextStyle(
                color: color.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _localizedRuntimeText(BuildContext context, String text) {
  if (LanguageScope.of(context) != 'en') {
    return text;
  }
  const exact = {
    '尚未執行更新': 'Update not run yet',
    '尚未檢查後端狀態': 'Backend status not checked yet',
    '尚無本地資料': 'No local data yet',
    '已載入本地資料': 'Local data loaded',
    '設定已儲存': 'Settings saved',
    '正在讀取本地輸出資料': 'Reading local output data',
    '正在執行 SVN 增量更新': 'Running SVN incremental update',
    '更新完成，已重新載入資料': 'Update completed and data reloaded',
    '更新未完成': 'Update not completed',
  };
  return exact[text] ?? text;
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(child: SelectableText(error)),
        ],
      ),
    );
  }
}

class _EmptyDataCard extends StatelessWidget {
  const _EmptyDataCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final panelBg = theme.brightness == Brightness.dark
        ? _cyberBackground
        : _aura(context).surfaceAlt;

    return Material(
      color: panelBg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_download_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                _t(context, '尚無輸出資料', 'No Output Data'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  context,
                  '選擇 SVN 庫後按下「執行增量更新」，UI 會讀取 loader 產生的 JSON 與 CSV 分片。',
                  'Select an SVN repository and run an incremental update. The UI will load the JSON and CSV shards generated by the loader.',
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

String _joinPath(String first, String second, [String? third, String? fourth]) {
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
