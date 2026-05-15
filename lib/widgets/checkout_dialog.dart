import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aura_svn/app_theme.dart';
import 'package:aura_svn/language_scope.dart';
import 'package:aura_svn/notes_store.dart';
import 'package:aura_svn/utils/command_line.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showCheckoutDialog(
  BuildContext context, {
  String initialRepoUrl = '',
  String initialRevision = '',
  String svnCommand = '',
  String svnCommandParameters = '',
  String username = '',
  String password = '',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => LanguageScope(
      languageCode: LanguageScope.of(context),
      child: CheckoutDialog(
        initialRepoUrl: initialRepoUrl,
        initialRevision: initialRevision,
        svnCommand: svnCommand,
        svnCommandParameters: svnCommandParameters,
        username: username,
        password: password,
      ),
    ),
  );
}

class CheckoutDialog extends StatefulWidget {
  const CheckoutDialog({
    super.key,
    this.initialRepoUrl = '',
    this.initialRevision = '',
    this.svnCommand = '',
    this.svnCommandParameters = '',
    this.username = '',
    this.password = '',
  });

  final String initialRepoUrl;
  final String initialRevision;
  final String svnCommand;
  final String svnCommandParameters;
  final String username;
  final String password;

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  late final TextEditingController _repoUrlController;
  final _workingCopyController = TextEditingController();
  final _revisionController = TextEditingController();
  final _logScrollController = ScrollController();

  bool _isRunning = false;
  bool _isDone = false;
  bool _hasFailed = false;
  final _logs = <String>[];
  Process? _process;

  @override
  void initState() {
    super.initState();
    _repoUrlController = TextEditingController(text: widget.initialRepoUrl);
    _revisionController.text = widget.initialRevision.trim();
  }

  @override
  void dispose() {
    _repoUrlController.dispose();
    _workingCopyController.dispose();
    _revisionController.dispose();
    _logScrollController.dispose();
    _process?.kill();
    super.dispose();
  }

  Future<void> _pickDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: t(context, '選擇 Working Copy 目錄', 'Select Working Copy Directory'),
    );
    if (path != null && mounted) {
      setState(() => _workingCopyController.text = path);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _appendLog(String line) {
    if (!mounted) return;
    setState(() => _logs.add(line));
    _scrollToBottom();
  }

  Future<void> _runCheckout() async {
    final repoUrl = _repoUrlController.text.trim();
    final workingCopy = _workingCopyController.text.trim();

    if (repoUrl.isEmpty || workingCopy.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t(context, '請填寫 Repository URL 與 Working Copy 路徑', 'Please fill in Repository URL and Working Copy path')),
        ),
      );
      return;
    }

    final svnCmd = widget.svnCommand.trim().isEmpty ? defaultSvnCommand() : widget.svnCommand.trim();
    final svnParts = splitCommandLine(svnCmd);
    if (svnParts.isEmpty) return;

    final extraArgs = widget.svnCommandParameters.trim().isEmpty
        ? splitCommandLine(defaultSvnParameters())
        : splitCommandLine(widget.svnCommandParameters.trim());

    final revText = _revisionController.text.trim();
    final args = [
      ...svnParts.skip(1),
      'checkout',
      repoUrl,
      workingCopy,
      ...extraArgs,
      if (widget.username.isNotEmpty) ...['--username', widget.username],
      if (widget.password.isNotEmpty) ...['--password', widget.password],
      if (revText.isNotEmpty) ...['-r', revText],
    ];

    setState(() {
      _isRunning = true;
      _isDone = false;
      _hasFailed = false;
      _logs
        ..clear()
        ..add('RUN  ${svnParts.join(' ')} checkout $repoUrl $workingCopy${revText.isNotEmpty ? ' -r $revText' : ''}');
    });

    try {
      final process = await Process.start(svnParts.first, args, runInShell: false);
      _process = process;

      Future<void> listen(Stream<List<int>> stream, {bool isError = false}) {
        return stream
            .transform(const Utf8Decoder(allowMalformed: true))
            .transform(const LineSplitter())
            .listen((line) => _appendLog(isError ? 'ERR  $line' : line))
            .asFuture<void>();
      }

      final exitCode = await Future.wait([
        listen(process.stdout),
        listen(process.stderr, isError: true),
        process.exitCode,
      ]).then((results) => results[2] as int);

      _process = null;
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _isDone = true;
        _hasFailed = exitCode != 0;
        _logs.add(exitCode == 0
            ? '✓  Checkout 完成'
            : '✗  失敗，exit code=$exitCode');
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _isDone = true;
        _hasFailed = true;
        _logs.add('ERR  $e');
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final a = aura(context);
    // 關閉 M3 Dialog／按鈕的 surface tint 與 fromSeed 偏暖 secondary，改為冷色主題。
    final dialogBg = isDark ? cyberMainPanel : theme.colorScheme.surface;
    final onAccentFg = isDark ? cyberMainPanel : Colors.white;
    final checkoutTheme = theme.copyWith(
      dialogTheme: theme.dialogTheme.copyWith(
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        backgroundColor: dialogBg,
      ),
      colorScheme: theme.colorScheme.copyWith(
        primary: isDark ? cyberAccent : a.accent,
        onPrimary: onAccentFg,
        surface: isDark ? cyberSurfaceAlt : theme.colorScheme.surface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: isDark ? cyberAccent : a.accent,
          foregroundColor: onAccentFg,
          disabledBackgroundColor: a.textMuted.withOpacity(0.22),
          disabledForegroundColor: a.textMuted.withOpacity(0.55),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: a.textMuted,
          side: BorderSide(color: a.border.withOpacity(isDark ? 0.55 : 0.75)),
        ),
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        fillColor: isDark ? cyberSurfaceAlt : a.surfaceAlt,
        prefixIconColor: isDark ? cyberTextMuted : a.textMuted,
      ),
    );

    return Theme(
      data: checkoutTheme,
      child: Dialog(
        backgroundColor: dialogBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: a.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700, minWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: a.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.download_for_offline_rounded, color: a.accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t(context, 'SVN Checkout', 'SVN Checkout'),
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          t(context, '將 SVN 庫取出至本機目錄', 'Check out an SVN repository to a local directory'),
                          style: theme.textTheme.bodySmall?.copyWith(color: a.textSubtle),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _isRunning ? null : () => Navigator.of(context).pop(),
                    color: a.textSubtle,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Divider(color: a.border.withOpacity(0.5), height: 24),

              // ── Repo URL ─────────────────────────────────────────────
              _Field(
                label: t(context, 'Repository URL', 'Repository URL'),
                controller: _repoUrlController,
                hintText: 'svn://server/project/trunk',
                prefixIcon: const Icon(Icons.storage_rounded),
                enabled: !_isRunning,
              ),
              const SizedBox(height: 14),

              // ── Working Copy Path ─────────────────────────────────────
              _Field(
                label: t(context, 'Working Copy 路徑', 'Working Copy Path'),
                controller: _workingCopyController,
                hintText: r'C:\Projects\MyProject',
                prefixIcon: const Icon(Icons.folder_open_rounded),
                enabled: !_isRunning,
                suffix: Tooltip(
                  message: t(context, '選擇資料夾', 'Browse folder'),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: _isRunning ? null : _pickDirectory,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      decoration: BoxDecoration(
                        color: a.accent.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: a.accent.withOpacity(0.25)),
                      ),
                      child: Icon(Icons.folder_rounded, color: a.accent, size: 18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ── Revision ──────────────────────────────────────────────
              _Field(
                label: t(context, 'Revision（選填，留空為 HEAD）', 'Revision (optional, blank = HEAD)'),
                controller: _revisionController,
                hintText: 'HEAD',
                prefixIcon: const Icon(Icons.tag_rounded),
                enabled: !_isRunning,
              ),

              // ── Output log ────────────────────────────────────────────
              if (_logs.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: isDark ? cyberMainPanel : a.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _hasFailed
                          ? Colors.red.shade700.withOpacity(0.5)
                          : _isDone
                              ? a.accent.withOpacity(0.4)
                              : a.border,
                    ),
                  ),
                  child: ListView.builder(
                    controller: _logScrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    itemCount: _logs.length,
                    itemBuilder: (context, i) {
                      final line = _logs[i];
                      final Color lineColor;
                      if (line.startsWith('ERR  ') || line.startsWith('✗')) {
                        lineColor = const Color(0xFFFF6B6B);
                      } else if (line.startsWith('RUN  ')) {
                        lineColor = a.textSubtle;
                      } else if (line.startsWith('✓')) {
                        lineColor = a.accent;
                      } else {
                        lineColor = a.textMuted;
                      }
                      return Text(
                        line,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.5,
                          height: 1.6,
                          color: lineColor,
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ── Actions ───────────────────────────────────────────────
              Row(
                children: [
                  if (_isDone && !_hasFailed) ...[
                    Icon(Icons.check_circle_rounded, color: a.accent, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      t(context, '完成', 'Done'),
                      style: TextStyle(color: a.accent, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ],
                  if (_isRunning) ...[
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: a.accent),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      t(context, '執行中…', 'Running…'),
                      style: TextStyle(color: a.textMuted, fontSize: 13),
                    ),
                  ],
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _isRunning ? null : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(t(context, '關閉', 'Close')),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _isRunning ? null : _runCheckout,
                    icon: const Icon(Icons.download_for_offline_rounded),
                    label: Text(t(context, 'Checkout', 'Checkout')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hintText,
    this.prefixIcon,
    this.enabled = true,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final Widget? prefixIcon;
  final bool enabled;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: aura(context).text,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                decoration: InputDecoration(
                  hintText: hintText,
                  prefixIcon: prefixIcon,
                ),
              ),
            ),
            if (suffix != null) ...[
              const SizedBox(width: 8),
              suffix!,
            ],
          ],
        ),
      ],
    );
  }
}
