import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'aura_theme.dart';
import 'localization.dart';
import 'models.dart';
import 'utils.dart';

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

class ProjectReportButton extends StatefulWidget {
  const ProjectReportButton({
    super.key,
    required this.repository,
    required this.settings,
  });

  final SvnRepository repository;
  final AppSettings settings;

  @override
  State<ProjectReportButton> createState() => _ProjectReportButtonState();
}

class _ProjectReportButtonState extends State<ProjectReportButton> {
  bool _isRunning = false;

  Future<void> _generate() async {
    setState(() {
      _isRunning = true;
    });

    try {
      final languageCode = LanguageScope.of(context);
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        builder: (context) => LanguageScope(
          languageCode: languageCode,
          child: _ProjectReportConsoleSheet(
            repository: widget.repository,
            settings: widget.settings,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _isRunning ? null : _generate,
      icon: _isRunning
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_awesome_rounded),
      label: Text(
        _isRunning
            ? _t(context, 'AI 分析中', 'AI Analyzing')
            : _t(context, 'AI 專案分析', 'AI Project Analysis'),
      ),
    );
  }
}

class ProjectReportAnalysisPage extends StatelessWidget {
  const ProjectReportAnalysisPage({
    super.key,
    required this.repository,
    required this.settings,
    required this.titleController,
    required this.promptController,
    required this.onBack,
  });

  final SvnRepository repository;
  final AppSettings settings;
  final TextEditingController titleController;
  final TextEditingController promptController;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
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
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${repository.name} ${_t(context, 'AI 專案分析', 'AI Project Analysis')}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Card(
            child: _ProjectReportConsoleSheet(
              repository: repository,
              settings: settings,
              titleController: titleController,
              promptController: promptController,
            ),
          ),
        ),
      ],
    );
  }
}

class ProjectReportHistoryPage extends StatefulWidget {
  const ProjectReportHistoryPage({
    super.key,
    required this.repository,
    required this.settings,
    required this.onBack,
  });

  final SvnRepository repository;
  final AppSettings settings;
  final VoidCallback onBack;

  @override
  State<ProjectReportHistoryPage> createState() =>
      _ProjectReportHistoryPageState();
}

class _ProjectReportHistoryPageState extends State<ProjectReportHistoryPage> {
  late Future<List<ProjectReportResult>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ProjectReportResult>> _load() {
    return _loadProjectReportHistory(
      settings: widget.settings,
      repository: widget.repository,
    );
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openReport(ProjectReportResult result) async {
    final languageCode = LanguageScope.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => LanguageScope(
        languageCode: languageCode,
        child: _ProjectReportDialog(result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _t(context, '瀏覽歷史AI分析', 'Browse AI Analysis History'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        widget.repository.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _aura(context).textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(_t(context, '重新整理', 'Refresh')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: FutureBuilder<List<ProjectReportResult>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _HistoryMessage(
                      icon: Icons.error_outline_rounded,
                      title: _t(context, '讀取歷史分析失敗', 'Failed to Load History'),
                      message: snapshot.error.toString(),
                    );
                  }
                  final reports = snapshot.data ?? const [];
                  if (reports.isEmpty) {
                    return _HistoryMessage(
                      icon: Icons.history_edu_rounded,
                      title: _t(context, '尚無歷史AI分析', 'No AI Analysis History'),
                      message: _t(
                        context,
                        '目前 Repo 還沒有儲存過 AI 分析報告。',
                        'This repository does not have saved AI analysis reports yet.',
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: reports.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final report = reports[index];
                      return _ProjectReportHistoryTile(
                        result: report,
                        onOpen: () => _openReport(report),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProjectReportHistoryTile extends StatelessWidget {
  const _ProjectReportHistoryTile({
    required this.result,
    required this.onOpen,
  });

  final ProjectReportResult result;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = result.title.trim().isEmpty
        ? _t(context, '未命名分析報告', 'Untitled Analysis Report')
        : result.title.trim();

    return Material(
      color: _aura(context).surfaceAlt,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                child: Icon(
                  Icons.article_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.schedule_rounded, size: 16),
                          label: Text(_formatReportDate(result.createdAt)),
                        ),
                        if (result.model.isNotEmpty)
                          Chip(
                            avatar:
                                const Icon(Icons.smart_toy_rounded, size: 16),
                            label: Text(result.model),
                          ),
                      ],
                    ),
                    if (result.userPrompt.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        result.userPrompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _aura(context).textMuted,
                        ),
                      ),
                    ],
                    if (result.reportFile.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SelectableText(
                        result.reportFile,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _aura(context).textSubtle,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: _t(context, '開啟報告', 'Open Report'),
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _aura(context).surfaceAlt,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _aura(context).border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _aura(context).textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectReportConsoleSheet extends StatefulWidget {
  const _ProjectReportConsoleSheet({
    required this.repository,
    required this.settings,
    this.titleController,
    this.promptController,
  });

  final SvnRepository repository;
  final AppSettings settings;
  final TextEditingController? titleController;
  final TextEditingController? promptController;

  @override
  State<_ProjectReportConsoleSheet> createState() =>
      _ProjectReportConsoleSheetState();
}

class _ProjectReportConsoleSheetState
    extends State<_ProjectReportConsoleSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _promptController;
  late final bool _ownsTitleController;
  late final bool _ownsPromptController;
  final _logs = <ProjectReportLogEntry>[];
  bool _isRunning = false;
  bool _isCancelled = false;
  bool _hasStarted = false;
  String? _error;
  ProjectReportResult? _result;

  @override
  void initState() {
    super.initState();
    _ownsTitleController = widget.titleController == null;
    _ownsPromptController = widget.promptController == null;
    _titleController = widget.titleController ?? TextEditingController();
    _promptController = widget.promptController ?? TextEditingController();
    if (_titleController.text.trim().isEmpty) {
      _titleController.text =
          _defaultProjectReportTitle(widget.repository.name);
    }
  }

  @override
  void dispose() {
    if (_ownsTitleController) {
      _titleController.dispose();
    }
    if (_ownsPromptController) {
      _promptController.dispose();
    }
    super.dispose();
  }

  void _cancel() {
    if (!_isRunning) {
      return;
    }
    setState(() {
      _isCancelled = true;
      _isRunning = false;
    });
    _addLogText('已取消分析', level: 'warn');
  }

  Future<void> _run() async {
    if (_isRunning) {
      return;
    }
    _isCancelled = false;
    final reportTitle = _titleController.text.trim();
    final userPrompt = _promptController.text.trim();
    setState(() {
      _isRunning = true;
      _hasStarted = true;
      _error = null;
      _result = null;
      _logs.clear();
    });
    _addLogText('Console 已啟動，準備呼叫本地後端');
    _addLogText('報告標題：${reportTitle.isEmpty ? '(由後端自動產生)' : reportTitle}');
    if (userPrompt.isNotEmpty) {
      _addLogText('使用者 prompt：$userPrompt');
    } else {
      _addLogText('未輸入使用者 prompt，將產生一般專案級報告');
    }
    try {
      final result = await _generateProjectReportStream(
        settings: widget.settings,
        repository: widget.repository,
        reportTitle: reportTitle,
        userPrompt: userPrompt,
        onLog: _addLog,
      );
      if (!mounted || _isCancelled) {
        return;
      }
      setState(() {
        _result = result;
        _isRunning = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openReportDialog(result);
        }
      });
    } catch (error) {
      if (!mounted || _isCancelled) {
        return;
      }
      _addLogText('專案級報告失敗：$error', level: 'error');
      setState(() {
        _error = error.toString();
        _isRunning = false;
      });
    }
  }

  void _addLog(ProjectReportLogEntry entry) {
    if (!mounted) {
      return;
    }
    setState(() {
      _logs.add(entry);
    });
  }

  void _addLogText(String message, {String level = 'info'}) {
    _addLog(ProjectReportLogEntry(
      level: level,
      message: message,
      time: DateTime.now(),
    ));
  }

  Future<void> _openReportDialog(ProjectReportResult result) async {
    final languageCode = LanguageScope.of(context);
    await showDialog<void>(
      context: context,
      builder: (context) => LanguageScope(
        languageCode: languageCode,
        child: _ProjectReportDialog(result: result),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                child: Icon(
                  _error == null
                      ? Icons.auto_awesome_rounded
                      : Icons.error_outline_rounded,
                  color:
                      _error == null ? theme.colorScheme.primary : Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.repository.name} ${_t(context, 'AI 專案分析 Console', 'AI Analysis Console')}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      !_hasStarted
                          ? _t(
                              context,
                              'Model: ${widget.settings.ollamaModel}，等待輸入分析要求',
                              'Model: ${widget.settings.ollamaModel}, waiting for analysis prompt',
                            )
                          : _isRunning
                              ? _t(
                                  context,
                                  'Model: ${widget.settings.ollamaModel}，AI 正在分析中',
                                  'Model: ${widget.settings.ollamaModel}, AI is analyzing',
                                )
                              : _error == null
                                  ? _t(context, '已完成', 'Completed')
                                  : _t(
                                      context,
                                      '已停止，請查看 Console 錯誤',
                                      'Stopped. Check console errors.',
                                    ),
                    ),
                  ],
                ),
              ),
              if (_isRunning)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _titleController,
            enabled: !_isRunning,
            decoration: InputDecoration(
              labelText: _t(context, '報告標題', 'Report Title'),
              hintText: _t(
                context,
                '例如：登入逾時修改分析',
                'Example: Login timeout change analysis',
              ),
              prefixIcon: const Icon(Icons.title_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _promptController,
            enabled: !_isRunning,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: _t(context, '分析要求（可留空）', 'Analysis Prompt (optional)'),
              hintText: _t(
                context,
                '例如：幫我找有關於 xxxx 修改的 commit 節點，並給出分析報告',
                'Example: Find commits related to xxxx changes and produce an analysis report',
              ),
              prefixIcon: const Icon(Icons.manage_search_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _isRunning ? _cancel : _run,
                icon: _isRunning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(_result == null
                    ? _t(context, '開始分析', 'Start Analysis')
                    : _isRunning
                        ? _t(context, '取消', 'Cancel')
                        : _t(context, '重新分析', 'Analyze Again')),
              ),
              Text(
                _t(
                  context,
                  'Prompt 會送到本地後端，並納入 Ollama 分析上下文。',
                  'The prompt is sent to the local backend and included in the Ollama analysis context.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _aura(context).textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ConsolePanel(logs: _logs),
          if (_error != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              _error!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 12),
            _ReportReadyPanel(
              result: result,
              onOpenReport: () => _openReportDialog(result),
            ),
            Expanded(
              child: Center(
                child: Text(
                  _t(
                    context,
                    'Markdown 報告已在獨立彈出視窗顯示。你也可以按上方按鈕重新開啟。',
                    'The Markdown report is shown in a separate dialog. You can reopen it with the button above.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _aura(context).textMuted,
                  ),
                ),
              ),
            ),
          ] else
            Expanded(
              child: Center(
                child: Text(
                  !_hasStarted
                      ? _t(
                          context,
                          '請輸入分析要求後按「開始分析」。',
                          'Enter an analysis prompt and click Start Analysis.',
                        )
                      : _isRunning
                          ? _t(
                              context,
                              '等待 AI 回應中，Console 會持續保留目前進度。',
                              'Waiting for the AI response. The console will keep the current progress.',
                            )
                          : _t(
                              context,
                              '沒有產生報告內容。',
                              'No report content was generated.',
                            ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _aura(context).textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConsolePanel extends StatelessWidget {
  const _ConsolePanel({required this.logs});

  final List<ProjectReportLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    final text = logs.isEmpty
        ? _t(context, '尚無輸出', 'No output yet')
        : logs
            .map((log) =>
                '[${_formatLogTime(log.time)}] ${log.level.toUpperCase()}  ${log.message}')
            .join('\n');

    return Container(
      width: double.infinity,
      height: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: SingleChildScrollView(
        reverse: true,
        child: SelectableText(
          text,
          style: const TextStyle(
            color: Color(0xFFE2E8F0),
            fontFamily: 'monospace',
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _ReportReadyPanel extends StatelessWidget {
  const _ReportReadyPanel({
    required this.result,
    required this.onOpenReport,
  });

  final ProjectReportResult result;
  final VoidCallback onOpenReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _aura(context).surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _aura(context).border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.title.isEmpty
                      ? _t(context, 'Markdown 報告已產生',
                          'Markdown report generated')
                      : result.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: onOpenReport,
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(_t(context, '開啟報告視窗', 'Open Report')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (result.userPrompt.isNotEmpty) ...[
            _InfoLine(label: 'Prompt', value: result.userPrompt),
            const SizedBox(height: 8),
          ],
          _InfoLine(label: _t(context, '檔案', 'File'), value: result.reportFile),
        ],
      ),
    );
  }
}

class _ProjectReportDialog extends StatelessWidget {
  const _ProjectReportDialog({required this.result});

  final ProjectReportResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Dialog(
      insetPadding: const EdgeInsets.all(28),
      child: SizedBox(
        width: size.width * 0.9,
        height: size.height * 0.88,
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
                      Icons.article_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.title.isEmpty
                              ? '${result.repoName} ${_t(context, 'Markdown 分析報告', 'Markdown Analysis Report')}'
                              : result.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          result.userPrompt.isEmpty
                              ? 'Model: ${result.model}'
                              : 'Model: ${result.model} · Prompt: ${result.userPrompt}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _t(context, '關閉', 'Close'),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(child: _ReportContent(result)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportContent extends StatefulWidget {
  const _ReportContent(this.result);

  final ProjectReportResult result;

  @override
  State<_ReportContent> createState() => _ReportContentState();
}

class _ReportContentState extends State<_ReportContent> {
  String _saveStatus = '已由後端自動儲存';

  Future<void> _saveReport() async {
    final path = widget.result.reportFile.trim();
    if (path.isEmpty) {
      setState(() {
        _saveStatus = '沒有可儲存的報告路徑。';
      });
      return;
    }

    try {
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsString(widget.result.report, encoding: utf8);
      if (!mounted) {
        return;
      }
      setState(() {
        _saveStatus = '已儲存：${DateTime.now().toLocal()}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saveStatus = '儲存失敗：$error';
      });
    }
  }

  Future<void> _showInFileExplorer() async {
    final path = widget.result.reportFile.trim();
    if (path.isEmpty) {
      return;
    }

    try {
      if (Platform.isWindows) {
        await Process.start('explorer.exe', ['/select,$path']);
      } else {
        await Process.start('open', [File(path).parent.path]);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saveStatus = '開啟檔案位置失敗：$error';
      });
    }
  }

  Future<void> _copyMarkdown() async {
    await Clipboard.setData(ClipboardData(text: widget.result.report));
    if (!mounted) {
      return;
    }
    setState(() {
      _saveStatus = '已複製 Markdown 原文';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _aura(context).surfaceAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _aura(context).border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _saveReport,
                    icon: const Icon(Icons.save_rounded),
                    label: Text(_t(context, '另存新檔', 'Save As')),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showInFileExplorer,
                    icon: const Icon(Icons.folder_open_rounded),
                    label:
                        Text(_t(context, '在檔案總管顯示', 'Show in File Explorer')),
                  ),
                  OutlinedButton.icon(
                    onPressed: _copyMarkdown,
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(_t(context, '複製 Markdown', 'Copy Markdown')),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _InfoLine(
                  label: _t(context, '檔案', 'File'),
                  value: widget.result.reportFile),
              const SizedBox(height: 6),
              Text(
                _localizedReportSaveStatus(context, _saveStatus),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _aura(context).textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _aura(context).surfaceAlt,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _aura(context).border),
            ),
            child: Markdown(
              data: widget.result.report,
              selectable: true,
              padding: const EdgeInsets.all(18),
              styleSheet: _auraMarkdownStyle(context),
            ),
          ),
        ),
      ],
    );
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

String _formatLogTime(DateTime time) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
}

MarkdownStyleSheet _auraMarkdownStyle(BuildContext context) {
  final theme = Theme.of(context);
  final aura = _aura(context);
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    h1: theme.textTheme.headlineSmall?.copyWith(
      color: aura.text,
      fontWeight: FontWeight.w900,
    ),
    h2: theme.textTheme.titleLarge?.copyWith(
      color: aura.text,
      fontWeight: FontWeight.w900,
    ),
    h3: theme.textTheme.titleMedium?.copyWith(
      color: aura.text,
      fontWeight: FontWeight.w800,
    ),
    p: theme.textTheme.bodyMedium?.copyWith(
      color: aura.text,
      height: 1.55,
    ),
    listBullet: theme.textTheme.bodyMedium?.copyWith(color: aura.accent),
    code: TextStyle(
      color: theme.brightness == Brightness.dark
          ? const Color(0xFF7DD3FC)
          : const Color(0xFF0369A1),
      fontFamily: 'monospace',
      fontSize: 13,
      backgroundColor: aura.surfaceSoft,
    ),
    codeblockDecoration: BoxDecoration(
      color: aura.surfaceSoft,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: aura.border),
    ),
    codeblockPadding: const EdgeInsets.all(14),
    blockquote: theme.textTheme.bodyMedium?.copyWith(color: aura.textMuted),
    blockquoteDecoration: BoxDecoration(
      color: aura.surfaceSoft,
      borderRadius: BorderRadius.circular(12),
      border: Border(left: BorderSide(color: aura.accent, width: 4)),
    ),
    tableHead: theme.textTheme.bodyMedium?.copyWith(
      color: aura.text,
      fontWeight: FontWeight.w900,
    ),
    tableBody: theme.textTheme.bodyMedium?.copyWith(color: aura.text),
    tableBorder: TableBorder.all(color: aura.border),
    a: TextStyle(
      color: aura.accent,
      decoration: TextDecoration.underline,
    ),
  );
}

String _formatReportDate(DateTime? time) {
  if (time == null) {
    return '-';
  }
  String two(int value) => value.toString().padLeft(2, '0');
  final local = time.toLocal();
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String _localizedReportSaveStatus(BuildContext context, String status) {
  if (LanguageScope.of(context) != 'en') {
    return status;
  }
  if (status == '已由後端自動儲存') {
    return 'Automatically saved by backend';
  }
  if (status == '沒有可儲存的報告路徑。') {
    return 'No report path available for saving.';
  }
  if (status.startsWith('已儲存：')) {
    return 'Saved: ${status.substring('已儲存：'.length)}';
  }
  if (status.startsWith('儲存失敗：')) {
    return 'Save failed: ${status.substring('儲存失敗：'.length)}';
  }
  if (status.startsWith('開啟檔案位置失敗：')) {
    return 'Failed to open file location: ${status.substring('開啟檔案位置失敗：'.length)}';
  }
  if (status == '已複製 Markdown 原文') {
    return 'Copied Markdown source';
  }
  return status;
}

String _defaultProjectReportTitle(String repoName) {
  final now = DateTime.now();
  String two(int value) => value.toString().padLeft(2, '0');
  return '$repoName 專案級報告 ${now.year}-${two(now.month)}-${two(now.day)} ${two(now.hour)}:${two(now.minute)}';
}

Future<ProjectReportResult> _generateProjectReportStream({
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
      'notes_root': settings.notesRootPath,
      'ollama_base_url': settings.ollamaBaseUrl,
      'ollama_api_key': settings.ollamaApiKey,
      'model': settings.ollamaModel,
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

Future<List<ProjectReportResult>> _loadProjectReportHistory({
  required AppSettings settings,
  required SvnRepository repository,
}) async {
  if (settings.notesRootPath.trim().isEmpty) {
    throw Exception('請先到設定頁指定 Markdown 筆記根目錄。');
  }

  final decoded = await _backendPost(settings, '/api/reports/history', {
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

Future<Map<String, dynamic>> _backendPost(
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

DateTime? _parseDateTime(Object? value) {
  final text = value?.toString() ?? '';
  if (text.isEmpty) {
    return null;
  }
  return DateTime.tryParse(text);
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
  final DateTime? createdAt;
}
