import 'dart:convert';
import 'dart:io';

import 'package:aura_svn/app_theme.dart';
import 'package:aura_svn/language_scope.dart';
import 'package:aura_svn/models/project_report_log_entry.dart';
import 'package:aura_svn/models/svn_repository.dart';
import 'package:aura_svn/notes_store.dart';
import 'package:aura_svn/widgets/markdown_styles.dart';
import 'package:aura_svn/widgets/misc_widgets.dart';
import 'package:aura_svn/widgets/page_header_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

const double _kAiReportRadius = 5;

Color? _aiReportNightCardFill(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? cyberBase : null;

ShapeBorder _aiReportCardShape(BuildContext context) {
  final a = aura(context);
  final dark = Theme.of(context).brightness == Brightness.dark;
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(_kAiReportRadius),
    side: BorderSide(
      color: dark ? a.border : a.border.withOpacity(0.4),
    ),
  );
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
            ? t(context, 'AI 分析中', 'AI Analyzing')
            : t(context, 'AI 專案分析', 'AI Project Analysis'),
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
        AuraBackPageHeader(
          onBack: onBack,
          title: t(context, 'AI 專案分析', 'AI Project Analysis'),
          subtitle: repository.name,
        ),
        Expanded(
          child: Card(
            color: _aiReportNightCardFill(context),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: _aiReportCardShape(context),
            child: _ProjectReportConsoleSheet(
              repository: repository,
              settings: settings,
              titleController: titleController,
              promptController: promptController,
              showConsoleHeading: false,
            ),
          ),
        ),
      ],
    );
  }
}

/// SVN 專案 AI 對話助理（沿用舊版邏輯：組 prompt 後走 [generateProjectReportStream]）。
class ProjectChatMessage {
  const ProjectChatMessage({
    required this.role,
    required this.content,
  });

  final String role;
  final String content;
}

class ProjectChatPage extends StatefulWidget {
  const ProjectChatPage({
    super.key,
    required this.repository,
    required this.settings,
    required this.onBack,
  });

  final SvnRepository repository;
  final AppSettings settings;
  final VoidCallback onBack;

  @override
  State<ProjectChatPage> createState() => _ProjectChatPageState();
}

class _ProjectChatPageState extends State<ProjectChatPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <ProjectChatMessage>[];
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _messages.add(ProjectChatMessage(
      role: 'system',
      content: '''
你是這個 SVN 專案的 AI 對話助理。
請使用倉庫上下文回答問題，並在適當時主動詢問使用者是否要生成摘要報告。
如果使用者要求報告，請直接產生 Markdown 格式摘要報告。
你可以提出 SVN 指令或檔案查找建議，讓使用者在對話中進一步查詢。

倉庫名稱：${widget.repository.name}
Repository URL：${widget.repository.url}
''',
    ));
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) {
      return;
    }
    setState(() {
      _messages.add(ProjectChatMessage(role: 'user', content: trimmed));
      _inputController.clear();
      _isSending = true;
      _error = null;
    });

    final prompt = _buildPrompt();
    try {
      final result = await generateProjectReportStream(
        settings: widget.settings,
        repository: widget.repository,
        reportTitle:
            'Chat Assistant Response ${DateTime.now().toIso8601String()}',
        userPrompt: prompt,
        onLog: (_) {},
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(ProjectChatMessage(
          role: 'assistant',
          content: result.report.trim(),
        ));
        _isSending = false;
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isSending = false;
      });
    }
  }

  String _buildPrompt() {
    final buffer = StringBuffer();
    buffer.writeln('你是 SVN 倉庫的對話式 AI 助手。');
    buffer.writeln('請以簡潔、友善的方式回答問題。');
    buffer.writeln(
        '如果使用者沒有直接要求報告，請先回答問題，並主動詢問是否需要生成摘要報告。');
    buffer.writeln('如果需要，請直接生成 Markdown 格式摘要報告。');
    buffer.writeln('你可以建議使用者查詢哪些 SVN 指令或文件。');
    buffer.writeln();
    buffer.writeln('倉庫背景：');
    buffer.writeln('Repository Name: ${widget.repository.name}');
    buffer.writeln('Repository URL: ${widget.repository.url}');
    buffer.writeln();
    buffer.writeln('對話紀錄：');
    for (final message in _messages) {
      if (message.role == 'user') {
        buffer.writeln('User: ${message.content}');
      } else if (message.role == 'assistant') {
        buffer.writeln('Assistant: ${message.content}');
      }
    }
    return buffer.toString();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _pasteExample(String example) {
    _inputController.text = example;
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputController.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = aura(context);
    final isDark = theme.brightness == Brightness.dark;

    final examples = [
      t(
        context,
        '請分析這個 SVN 專案的分支狀態，並問我是否要生成摘要報告。',
        'Please analyze this SVN repository and ask me whether to generate a summary report.',
      ),
      t(
        context,
        '幫我找出最近一次 release 的關鍵變更，並詢問是否需要報告。',
        'Help me find the key changes from the latest release and ask if a report is needed.',
      ),
      t(
        context,
        '我想查詢與登入相關的檔案修改，建議我下一步怎麼做。',
        'I want to inspect login-related file changes; suggest next steps.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuraBackPageHeader(
          onBack: widget.onBack,
          title: t(context, 'AI 對話助理', 'AI Chat Assistant'),
          subtitle: t(
            context,
            '以對話提問；需要摘要報告時直接說明即可。',
            'Ask in chat; request a summary report when you need one.',
          ),
        ),
        Expanded(
          child: Card(
            color: _aiReportNightCardFill(context),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: _aiReportCardShape(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t(context, '提示範例', 'Prompt examples'),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: a.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: examples.map((example) {
                          return ActionChip(
                            label: Text(
                              example,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: a.text,
                                height: 1.35,
                              ),
                            ),
                            backgroundColor: isDark
                                ? cyberSurfaceAlt
                                : a.surfaceSoft,
                            side: BorderSide(color: a.border.withOpacity(0.65)),
                            onPressed: () => _pasteExample(example),
                          );
                        }).toList(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          t(context, '發生錯誤：', 'Error:'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          _error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        if (message.role == 'system') {
                          return const SizedBox.shrink();
                        }
                        final isUser = message.role == 'user';
                        return Align(
                          alignment: isUser
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.all(14),
                            constraints: const BoxConstraints(maxWidth: 820),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? (isDark
                                      ? cyberAccent.withOpacity(0.22)
                                      : theme.colorScheme.primaryContainer)
                                  : (isDark
                                      ? cyberSurfaceAlt
                                      : a.surfaceSoft),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isUser
                                    ? cyberAccent.withOpacity(0.45)
                                    : a.border.withOpacity(0.65),
                              ),
                            ),
                            child: isUser
                                ? SelectableText(
                                    message.content,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isDark
                                          ? stitchPrimaryFixed
                                          : theme.colorScheme.onPrimaryContainer,
                                    ),
                                  )
                                : MarkdownBody(
                                    data: message.content,
                                    selectable: true,
                                    styleSheet: auraMarkdownStyle(context),
                                  ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          minLines: 1,
                          maxLines: 4,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: a.text,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor:
                                isDark ? cyberMainPanel : theme.colorScheme.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: a.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: a.border.withOpacity(0.75),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark ? cyberAccent : a.accent,
                                width: 1.4,
                              ),
                            ),
                            hintText: t(
                              context,
                              '輸入你的問題，或請我生成摘要報告...',
                              'Type your question or ask for a summary report...',
                            ),
                            hintStyle: TextStyle(color: a.textMuted),
                          ),
                          onSubmitted: _sendMessage,
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _isSending
                            ? null
                            : () => _sendMessage(_inputController.text),
                        child: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(t(context, '送出', 'Send')),
                      ),
                    ],
                  ),
                ),
              ],
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
    return loadProjectReportHistory(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuraBackPageHeader(
          onBack: widget.onBack,
          title: t(context, '瀏覽歷史AI分析', 'Browse AI Analysis History'),
          subtitle: widget.repository.name,
          trailing: OutlinedButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(t(context, '重新整理', 'Refresh')),
          ),
        ),
        Expanded(
          child: Card(
            color: _aiReportNightCardFill(context),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            shape: _aiReportCardShape(context),
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
                      title: t(context, '讀取歷史分析失敗', 'Failed to Load History'),
                      message: snapshot.error.toString(),
                    );
                  }
                  final reports = snapshot.data ?? const [];
                  if (reports.isEmpty) {
                    return _HistoryMessage(
                      icon: Icons.history_edu_rounded,
                      title: t(context, '尚無歷史AI分析', 'No AI Analysis History'),
                      message: t(
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
    final isDark = theme.brightness == Brightness.dark;
    final title = result.title.trim().isEmpty
        ? t(context, '未命名分析報告', 'Untitled Analysis Report')
        : result.title.trim();

    return Material(
      color: isDark ? cyberBase : aura(context).surfaceAlt,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kAiReportRadius),
        side: BorderSide(color: aura(context).border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(_kAiReportRadius),
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
                        fontWeight: FontWeight.w600,
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
                          color: aura(context).textMuted,
                        ),
                      ),
                    ],
                    if (result.reportFile.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SelectableText(
                        result.reportFile,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: aura(context).textSubtle,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: t(context, '開啟報告', 'Open Report'),
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
          color: Theme.of(context).brightness == Brightness.dark
              ? cyberBase
              : aura(context).surfaceAlt,
          borderRadius: BorderRadius.circular(_kAiReportRadius),
          border: Border.all(color: aura(context).border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: aura(context).textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiReportLabeledField extends StatelessWidget {
  const _AiReportLabeledField({
    required this.label,
    required this.controller,
    this.hintText,
    this.prefixIcon,
    this.enabled = true,
    this.minLines,
    this.maxLines,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final Widget? prefixIcon;
  final bool enabled;
  final int? minLines;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
            color: aura(context).text,
            letterSpacing: 0,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon,
          ),
        ),
      ],
    );
  }
}

class _ProjectReportConsoleSheet extends StatefulWidget {
  const _ProjectReportConsoleSheet({
    required this.repository,
    required this.settings,
    this.titleController,
    this.promptController,
    this.showConsoleHeading = true,
  });

  final SvnRepository repository;
  final AppSettings settings;
  final TextEditingController? titleController;
  final TextEditingController? promptController;
  /// 為 false 時不顯示「AI查詢」大標（頁面頂列已顯示時使用）。
  final bool showConsoleHeading;

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

  Future<void> _run() async {
    if (_isRunning) {
      return;
    }
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
      final result = await generateProjectReportStream(
        settings: widget.settings,
        repository: widget.repository,
        reportTitle: reportTitle,
        userPrompt: userPrompt,
        onLog: _addLog,
      );
      if (!mounted) {
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
      if (!mounted) {
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
    final fieldTheme = theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: aura(context).border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: theme.colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5),
          borderSide: BorderSide(color: theme.colorScheme.error, width: 2),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          if (widget.showConsoleHeading)
            Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                child: Icon(
                  _error == null
                      ? Icons.auto_awesome_rounded
                      : Icons.error_outline_rounded,
                  size: 20,
                  color:
                      _error == null ? theme.colorScheme.primary : Colors.red,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(context, 'AI查詢', 'AI Query'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 24,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Model: ${widget.settings.ollamaModel}, Base URL: ${widget.settings.ollamaBaseUrl}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF00DBE7),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
          if (widget.showConsoleHeading) const SizedBox(height: 22),
          Theme(
            data: fieldTheme,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AiReportLabeledField(
                  label: t(context, '輸出文件標題', 'Output Document Title'),
                  controller: _titleController,
                  enabled: !_isRunning,
                  hintText: t(
                    context,
                    '例如：登入逾時修改分析',
                    'Example: Login timeout change analysis',
                  ),
                  prefixIcon: const Icon(Icons.title_rounded),
                ),
                const SizedBox(height: 12),
                _AiReportLabeledField(
                  label: t(
                    context,
                    '分析要求（可留空）',
                    'Analysis Prompt (optional)',
                  ),
                  controller: _promptController,
                  enabled: !_isRunning,
                  minLines: 2,
                  maxLines: 4,
                  hintText: t(
                    context,
                    '例如：幫我找有關於 xxxx 修改的 commit 節點，並給出分析報告',
                    'Example: Find commits related to xxxx changes and produce an analysis report',
                  ),
                  prefixIcon: const Icon(Icons.manage_search_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _isRunning ? null : _run,
                icon: _isRunning
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(_result == null
                    ? t(context, '開始分析', 'Start Analysis')
                    : t(context, '重新分析', 'Analyze Again')),
              ),
              Text(
                t(
                  context,
                  'Prompt 會送到本地後端，並納入 Ollama 分析上下文。',
                  'The prompt is sent to the local backend and included in the Ollama analysis context.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: aura(context).textMuted,
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 12),
            _ReportReadyPanel(
              result: result,
              onOpenReport: () => _openReportDialog(result),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  t(
                    context,
                    'Markdown 報告已在獨立彈出視窗顯示。你也可以按上方按鈕重新開啟。',
                    'The Markdown report is shown in a separate dialog. You can reopen it with the button above.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: aura(context).textMuted,
                  ),
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  !_hasStarted
                      ? t(
                          context,
                          '請輸入分析要求後按「開始分析」。',
                          'Enter an analysis prompt and click Start Analysis.',
                        )
                      : _isRunning
                          ? t(
                              context,
                              '等待 AI 回應中，Console 會持續保留目前進度。',
                              'Waiting for the AI response. The console will keep the current progress.',
                            )
                          : t(
                              context,
                              '沒有產生報告內容。',
                              'No report content was generated.',
                            ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: aura(context).textMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
        ),
      ),
    );
  }
}

class _ConsolePanel extends StatelessWidget {
  const _ConsolePanel({required this.logs});

  final List<ProjectReportLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final a = aura(context);
    final text = logs.isEmpty
        ? t(context, '尚無輸出', 'No output yet')
        : logs
            .map((log) =>
                '[${_formatLogTime(log.time)}] ${log.level.toUpperCase()}  ${log.message}')
            .join('\n');

    return Container(
      width: double.infinity,
      height: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? cyberBase : a.surfaceAlt,
        borderRadius: BorderRadius.circular(_kAiReportRadius),
        border: Border.all(color: a.border),
      ),
      child: SingleChildScrollView(
        reverse: true,
        child: SelectableText(
          text,
          style: TextStyle(
            color: isDark ? const Color(0xFFE2E8F0) : a.text,
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? cyberBase : aura(context).surfaceAlt,
        borderRadius: BorderRadius.circular(_kAiReportRadius),
        border: Border.all(color: aura(context).border),
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
                      ? t(context, 'Markdown 報告已產生',
                          'Markdown report generated')
                      : result.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: onOpenReport,
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(t(context, '開啟報告視窗', 'Open Report')),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (result.userPrompt.isNotEmpty) ...[
            InfoLine(label: 'Prompt', value: result.userPrompt),
            const SizedBox(height: 8),
          ],
          InfoLine(label: t(context, '檔案', 'File'), value: result.reportFile),
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
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.all(28),
      backgroundColor: isDark ? cyberBase : null,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kAiReportRadius),
        side: BorderSide(color: aura(context).border),
      ),
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
                              ? '${result.repoName} ${t(context, 'Markdown 分析報告', 'Markdown Analysis Report')}'
                              : result.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
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
                    tooltip: t(context, '關閉', 'Close'),
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
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? cyberBase : aura(context).surfaceAlt,
            borderRadius: BorderRadius.circular(_kAiReportRadius),
            border: Border.all(color: aura(context).border),
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
                    label: Text(t(context, '重新儲存', 'Save Again')),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showInFileExplorer,
                    icon: const Icon(Icons.folder_open_rounded),
                    label:
                        Text(t(context, '在檔案總管顯示', 'Show in File Explorer')),
                  ),
                  OutlinedButton.icon(
                    onPressed: _copyMarkdown,
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(t(context, '複製 Markdown', 'Copy Markdown')),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              InfoLine(
                  label: t(context, '檔案', 'File'),
                  value: widget.result.reportFile),
              const SizedBox(height: 6),
              Text(
                _localizedReportSaveStatus(context, _saveStatus),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: aura(context).textMuted,
                  fontWeight: FontWeight.w600,
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
              color: isDark ? cyberBase : aura(context).surfaceAlt,
              borderRadius: BorderRadius.circular(_kAiReportRadius),
              border: Border.all(color: aura(context).border),
            ),
            child: Markdown(
              data: widget.result.report,
              selectable: true,
              padding: const EdgeInsets.all(18),
              styleSheet: auraMarkdownStyle(context),
            ),
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
