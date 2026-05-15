import 'dart:io';

import 'package:aura_svn/app_theme.dart';
import 'package:aura_svn/chat_history_store.dart';
import 'package:aura_svn/language_scope.dart';
import 'package:aura_svn/models/chat_session.dart';
import 'package:aura_svn/models/svn_repository.dart';
import 'package:aura_svn/notes_store.dart';
import 'package:aura_svn/widgets/chat_history_panel.dart';
import 'package:aura_svn/widgets/markdown_styles.dart';
import 'package:aura_svn/widgets/page_header_widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

/// 依 [PersistedChatScope] 顯示目標範圍；未帶入之欄位不顯示。若三欄皆無則整塊不顯示。
class _AiChatScopeStrip extends StatelessWidget {
  const _AiChatScopeStrip({
    required this.repositoryName,
    required this.scope,
  });

  final String repositoryName;
  final PersistedChatScope scope;

  @override
  Widget build(BuildContext context) {
    final a = aura(context);
    final theme = Theme.of(context);

    final showPath = scope.svnPresent &&
        (scope.svnUrl != null && scope.svnUrl!.trim().isNotEmpty);
    final pathUrl = showPath ? scope.svnUrl!.trim() : '';

    final showBranch = scope.branchPresent;
    final branchRaw = scope.branchPath ?? '';
    final branchValue = !showBranch
        ? ''
        : (branchRaw.trim().isEmpty
            ? t(context, '（整個倉庫）', '(Whole repository)')
            : branchRaw.replaceAll('\n', ' '));

    final showCommit = scope.commitPresent;
    final commitValue = !showCommit
        ? ''
        : (scope.commitRevision != null
            ? 'r${scope.commitRevision}'
            : t(context, '（未指定單筆修訂）', '(No single revision)'));

    if (!showPath && !showBranch && !showCommit) {
      return const SizedBox.shrink();
    }

    final lineStyle = theme.textTheme.bodySmall?.copyWith(
      color: a.textMuted,
      height: 1.25,
      fontSize: 12,
    );
    final labelStyle =
        lineStyle?.copyWith(fontWeight: FontWeight.w700, color: a.textMuted);
    final valueStyle = lineStyle?.copyWith(
      fontWeight: FontWeight.w400,
      color: a.textSubtle,
    );

    final rowChildren = <Widget>[];
    void addCell(Widget cell) {
      if (rowChildren.isNotEmpty) {
        rowChildren.add(const SizedBox(width: 10));
      }
      rowChildren.add(Expanded(child: cell));
    }

    if (showPath) {
      addCell(
        _TargetScopeCell(
          child: Tooltip(
            message: repositoryName,
            waitDuration: const Duration(milliseconds: 450),
            child: SelectionArea(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'PATH: ', style: labelStyle),
                    TextSpan(text: pathUrl, style: valueStyle?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    )),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      );
    }
    if (showBranch) {
      addCell(
        _TargetScopeCell(
          child: SelectionArea(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Branch: ', style: labelStyle),
                  TextSpan(
                    text: branchValue,
                    style: valueStyle?.copyWith(
                      fontFamily:
                          branchRaw.trim().isNotEmpty ? 'monospace' : null,
                      fontSize: branchRaw.trim().isNotEmpty ? 12 : null,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }
    if (showCommit) {
      addCell(
        _TargetScopeCell(
          child: SelectionArea(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Commit: ', style: labelStyle),
                  TextSpan(
                    text: commitValue,
                    style: valueStyle?.copyWith(
                      fontFamily: scope.commitRevision != null
                          ? 'monospace'
                          : null,
                      fontFeatures: scope.commitRevision != null
                          ? const [FontFeature.tabularFigures()]
                          : null,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t(context, '目標範圍', 'Target scope'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: a.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: rowChildren,
        ),
      ],
    );
  }
}

class _TargetScopeCell extends StatelessWidget {
  const _TargetScopeCell({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final a = aura(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = a.border.withOpacity(isDark ? 0.28 : 0.38);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: borderColor, width: 0.75),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: child,
      ),
    );
  }
}

/// SVN 專案 AI助理（沿用舊版邏輯：組 prompt 後走 [generateProjectReportStream]）。
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
    this.focusBranchPath,
    this.focusCommitRevision,
  });

  final SvnRepository repository;
  final AppSettings settings;
  final VoidCallback onBack;
  /// 為 null 時代表僅針對整個倉庫（由主頁進入）。
  final String? focusBranchPath;
  /// 為 null 時代表未鎖定單一修訂；與 [focusBranchPath] 併用時為該分支上的修訂。
  final int? focusCommitRevision;

  @override
  State<ProjectChatPage> createState() => _ProjectChatPageState();
}

class _ProjectChatPageState extends State<ProjectChatPage> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <ProjectChatMessage>[];
  bool _isSending = false;
  String? _error;

  // Chat history / auto-save
  String? _sessionId;
  DateTime? _sessionCreatedAt;
  /// 自歷史載入的 `chat_scope`；null 表示沿用目前頁面（widget）範圍。
  PersistedChatScope? _scopeOverride;

  PersistedChatScope get _effectiveScope => _scopeOverride ??
      PersistedChatScope.fromLive(
        repository: widget.repository,
        focusBranchPath: widget.focusBranchPath,
        focusCommitRevision: widget.focusCommitRevision,
      );

  @override
  void initState() {
    super.initState();
    final branchBlock = _focusBranchBlockForSystem();
    final commitBlock = _focusCommitBlockForSystem();
    _messages.add(ProjectChatMessage(
      role: 'system',
      content: '''
你是這個 SVN 專案的 AI助理。
請使用倉庫上下文回答問題。

回覆風格規則：
- 如果使用者明確要求報告，直接產生完整 Markdown 格式報告，結尾不要再詢問是否需要報告。
- 如果你的回覆本身已包含多個章節、條列、或程式碼區塊等結構化內容，視同已提供報告，結尾不要再詢問是否需要報告。
- 只有在回覆是簡短的對話式回答（無結構化內容）時，才可以詢問是否需要進一步產出正式摘要報告。
- 不要在同一則回覆中既產出結構化報告、又詢問是否需要報告，這會造成矛盾。

你可以提出 SVN 指令或檔案查找建議，讓使用者在對話中進一步查詢。

倉庫名稱：${widget.repository.name}
Repository URL：${widget.repository.url}
$branchBlock$commitBlock''',
    ));
    _inputController.addListener(_onChatInputChanged);
  }

  void _onChatInputChanged() {
    if (mounted) setState(() {});
  }

  /// 與輸入框 [TextField] 的換行邏輯對齊，用於判斷是否為單行以置中送出鈕。
  int _chatInputLineCount({
    required String text,
    required double innerMaxWidth,
    required TextStyle style,
    required TextScaler textScaler,
  }) {
    if (innerMaxWidth <= 1) {
      return 1;
    }
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      text: TextSpan(
        text: text.isEmpty ? ' ' : text,
        style: style,
      ),
    )..layout(maxWidth: innerMaxWidth);
    final metrics = painter.computeLineMetrics();
    return metrics.isEmpty ? 1 : metrics.length;
  }

  String _focusBranchBlockForSystem() {
    final p = widget.focusBranchPath?.trim();
    if (p == null || p.isEmpty) {
      return '';
    }
    return '''

目前對話關注分支（SVN 路徑）：$p
請優先以此分支的變更與脈絡回答；若使用者未指定其他範圍，預設在此分支上思考。''';
  }

  String _focusCommitBlockForSystem() {
    final r = widget.focusCommitRevision;
    if (r == null) {
      return '';
    }
    return '''

目前對話關注修訂版本：r$r
請優先以此修訂的變更內容回答；若使用者未指定其他範圍，預設以此修訂為主。''';
  }

  @override
  void didUpdateWidget(covariant ProjectChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository.name != widget.repository.name ||
        oldWidget.repository.url != widget.repository.url ||
        oldWidget.focusBranchPath != widget.focusBranchPath ||
        oldWidget.focusCommitRevision != widget.focusCommitRevision) {
      setState(() {
        _scopeOverride = null;
      });
    }
  }

  @override
  void dispose() {
    _inputController.removeListener(_onChatInputChanged);
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
            'AI Assistant Response ${DateTime.now().toIso8601String()}',
        userPrompt: prompt,
        onLog: (_) {},
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(ProjectChatMessage(
          role: 'assistant',
          content: _appendAssistantScopeSignatureMarkdown(
            result.report.trim(),
            context,
          ),
        ));
        _isSending = false;
      });
      _scrollToBottom();
      _autoSave();
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
    buffer.writeln();
    buffer.writeln('【回覆風格規則】');
    buffer.writeln('1. 如果使用者明確要求報告，直接產生完整 Markdown 格式報告，結尾不要再詢問是否需要報告。');
    buffer.writeln('2. 如果你的回覆本身已包含多個章節標題（##）、條列項目、或程式碼區塊等結構化內容，'
        '視同已提供報告，結尾絕對不要再詢問「是否需要報告」，避免矛盾。');
    buffer.writeln('3. 只有在回覆是短篇的對話式回答（無結構化 Markdown 內容）時，'
        '才可以在最後詢問是否需要進一步產出正式摘要報告。');
    buffer.writeln('4. 嚴禁在同一則回覆中既產出結構化 Markdown 報告、又詢問是否需要報告。');
    buffer.writeln();
    buffer.writeln('你可以建議使用者查詢哪些 SVN 指令或文件。');
    buffer.writeln();
    buffer.writeln('倉庫背景：');
    buffer.writeln('Repository Name: ${widget.repository.name}');
    final scope = _effectiveScope;
    final urlForPrompt = scope.svnPresent &&
            (scope.svnUrl != null && scope.svnUrl!.trim().isNotEmpty)
        ? scope.svnUrl!.trim()
        : widget.repository.url;
    buffer.writeln('Repository URL: $urlForPrompt');
    if (scope.branchPresent) {
      final raw = scope.branchPath ?? '';
      if (raw.trim().isNotEmpty) {
        buffer.writeln('Focus Branch (SVN path): $raw');
      }
    }
    if (scope.commitPresent && scope.commitRevision != null) {
      buffer.writeln('Focus Revision: r${scope.commitRevision}');
    }
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

  /// 在 AI 產生的 Markdown 結尾空一行後加上「本文範圍」區塊（GitHub NOTE 語法），供顯示與下載 MD 一致。
  String _appendAssistantScopeSignatureMarkdown(
    String body,
    BuildContext context,
  ) {
    final line = _markdownScopeNoteLine(context);
    return '$body\n\n> [!NOTE]\n'
        '> 本文範圍：$line\n';
  }

  String _markdownScopeNoteLine(BuildContext context) {
    final scope = _effectiveScope;
    final repo = widget.repository.name.replaceAll('\n', ' ').trim();
    final parts = <String>['Project: $repo'];
    if (scope.branchPresent) {
      final raw = scope.branchPath ?? '';
      final branch = raw.trim().isEmpty
          ? t(context, '（整個倉庫）', '(Whole repository)')
          : raw.replaceAll('\n', ' ');
      parts.add('Branch: $branch');
    }
    if (scope.commitPresent) {
      final rev = scope.commitRevision;
      parts.add(
        rev != null
            ? 'Commit: r$rev'
            : t(context, '（未指定單筆修訂）', '(No single revision)'),
      );
    }
    return parts.join(', ');
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

  // ── History / auto-save ───────────────────────────────────────────────────

  Future<void> _autoSave() async {
    if (widget.settings.notesRootPath.isEmpty) return;

    // Collect only user/assistant messages (skip system)
    final msgs = _messages
        .where((m) => m.role == 'user' || m.role == 'assistant')
        .map((m) => {'role': m.role, 'content': m.content})
        .toList();
    if (msgs.isEmpty) return;

    final now = DateTime.now();
    _sessionId ??= ChatSession.generateId(widget.repository.name);
    _sessionCreatedAt ??= now;

    final firstUserContent =
        msgs.firstWhere((m) => m['role'] == 'user',
            orElse: () => {'role': 'user', 'content': ''})['content'] ??
            '';

    final session = ChatSession(
      id: _sessionId!,
      repoName: widget.repository.name,
      title: ChatSession.titleFromFirstMessage(firstUserContent),
      createdAt: _sessionCreatedAt!,
      updatedAt: now,
      messages: msgs,
      chatScope: _effectiveScope,
    );

    await ChatHistoryStore.save(session, widget.settings.notesRootPath);
  }

  Future<void> _openHistory() async {
    if (widget.settings.notesRootPath.isEmpty) return;
    if (!mounted) return;

    final session = await showChatHistoryDialog(
      context: context,
      notesRootPath: widget.settings.notesRootPath,
      repoName: widget.repository.name,
    );
    if (session == null || !mounted) return;
    _restoreSession(session);
  }

  void _restoreSession(ChatSession session) {
    // Confirm if current chat already has messages
    final hasCurrentChat =
        _messages.any((m) => m.role == 'user' || m.role == 'assistant');

    if (hasCurrentChat) {
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(t(ctx, '載入對話記錄', 'Load Session')),
          content: Text(t(
            ctx,
            '目前的對話將被取代，確定要載入「${session.title}」嗎？',
            'Current chat will be replaced. Load "${session.title}"?',
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t(ctx, '取消', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t(ctx, '載入', 'Load')),
            ),
          ],
        ),
      ).then((confirmed) {
        if (confirmed == true) _applySession(session);
      });
    } else {
      _applySession(session);
    }
  }

  void _applySession(ChatSession session) {
    setState(() {
      // Keep system message at index 0, replace the rest
      final systemMsg =
          _messages.where((m) => m.role == 'system').toList();
      _messages
        ..clear()
        ..addAll(systemMsg)
        ..addAll(session.messages.map(
            (m) => ProjectChatMessage(role: m['role']!, content: m['content']!)));
      _sessionId = session.id;
      _sessionCreatedAt = session.createdAt;
      _scopeOverride = session.chatScope;
      _error = null;
    });
    _scrollToBottom();
  }

  // ─────────────────────────────────────────────────────────────────────────

  String _generateFilename(String content) {
    // Try first H1 or H2 heading
    final headingMatch =
        RegExp(r'^#{1,2}\s+(.+)$', multiLine: true).firstMatch(content);
    String base;
    if (headingMatch != null) {
      base = headingMatch.group(1)!;
    } else {
      // Fall back to first non-empty line
      base = content.split('\n').firstWhere(
            (l) => l.trim().isNotEmpty,
            orElse: () => 'ai_response',
          );
    }
    // Strip markdown inline symbols and path-unsafe characters
    base = base.replaceAll(RegExp(r'[*_`#\[\]()!]'), '');
    base = base.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    base = base.trim();
    if (base.length > 60) base = base.substring(0, 60).trim();
    if (base.isEmpty) base = 'ai_response';
    return '$base.md';
  }

  Future<void> _downloadMarkdown(BuildContext context, String content) async {
    final filename = _generateFilename(content);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: t(context, '儲存 Markdown', 'Save Markdown'),
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: ['md'],
    );
    if (path == null) return;
    await File(path).writeAsString(content);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t(context, '已儲存：$path', 'Saved: $path')),
        duration: const Duration(seconds: 3),
      ),
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
        '請分析這個 SVN 專案的分支狀態，並產生摘要報告。',
        'Please analyze this SVN repository and generate a summary report.',
      ),
      t(
        context,
        '幫我找出最近一次 release 的關鍵變更，並產生報告。',
        'Help me find the key changes from the latest release and generate a report.',
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
          title: t(context, 'AI助理', 'AI Assistant'),
          subtitle: t(
            context,
            '以對話提問；需要摘要報告時直接說明即可。',
            'Ask in chat; request a summary report when you need one.',
          ),
          trailing: Tooltip(
            message: 'History',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openHistory,
                borderRadius: BorderRadius.circular(22),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'History',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: isDark ? a.accent : a.textMuted,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.15,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.history_rounded,
                        size: 22,
                        color: isDark ? a.accent : a.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _AiChatScopeStrip(
            repositoryName: widget.repository.name,
            scope: _effectiveScope,
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
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: _ChatDownloadButton(
                                          onPressed: () => _downloadMarkdown(
                                              context, message.content),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      MarkdownBody(
                                        data: message.content,
                                        selectable: true,
                                        styleSheet: auraMarkdownStyle(context),
                                      ),
                                      const SizedBox(height: 6),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: _ChatDownloadButton(
                                          onPressed: () => _downloadMarkdown(
                                              context, message.content),
                                        ),
                                      ),
                                    ],
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 10.0;
                      const reservedForSend = 104.0;
                      const fieldHorizontalPadding = 24.0;
                      final inputStyle = theme.textTheme.bodyMedium
                          ?.copyWith(color: a.text);
                      final innerW = (constraints.maxWidth -
                              gap -
                              reservedForSend -
                              fieldHorizontalPadding)
                          .clamp(8.0, double.infinity);
                      final lineCount = inputStyle == null
                          ? 1
                          : _chatInputLineCount(
                              text: _inputController.text,
                              innerMaxWidth: innerW,
                              style: inputStyle,
                              textScaler: MediaQuery.textScalerOf(context),
                            );
                      final alignSingleLine = lineCount <= 1;

                      return Row(
                        crossAxisAlignment: alignSingleLine
                            ? CrossAxisAlignment.center
                            : CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _inputController,
                              minLines: 1,
                              maxLines: 4,
                              style: inputStyle,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark
                                    ? cyberMainPanel
                                    : theme.colorScheme.surface,
                                contentPadding:
                                    const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                          const SizedBox(width: gap),
                          FilledButton(
                            onPressed: _isSending
                                ? null
                                : () =>
                                    _sendMessage(_inputController.text),
                            child: _isSending
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(t(context, '送出', 'Send')),
                          ),
                        ],
                      );
                    },
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

class _ChatDownloadButton extends StatelessWidget {
  const _ChatDownloadButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final a = aura(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        Icons.download_rounded,
        size: 15,
        color: isDark ? a.accent : a.textMuted,
      ),
      label: Text(
        t(context, '下載 MD', 'Download MD'),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isDark ? a.accent : a.textMuted,
            ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

