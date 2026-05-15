import 'package:aura_svn/models/svn_repository.dart';

/// 單次 AI 對話存檔時的範圍（Path／Branch／Commit）；寫入 `chat_scope`。
///
/// 各欄位以 [xxxPresent] 表示 JSON 是否帶該鍵；未帶鍵表示舊檔或「不顯示該欄」。
/// [branchPath] 為 `''` 表示整庫（非特定分支）。
class PersistedChatScope {
  const PersistedChatScope({
    required this.svnPresent,
    this.svnUrl,
    required this.branchPresent,
    this.branchPath,
    required this.commitPresent,
    this.commitRevision,
  });

  final bool svnPresent;
  final String? svnUrl;
  final bool branchPresent;
  /// 有 [branchPresent] 時：`''` = 整庫；非空 = SVN 分支路徑。
  final String? branchPath;
  final bool commitPresent;
  final int? commitRevision;

  factory PersistedChatScope.fromLive({
    required SvnRepository repository,
    required String? focusBranchPath,
    required int? focusCommitRevision,
  }) {
    final b = focusBranchPath?.trim();
    return PersistedChatScope(
      svnPresent: true,
      svnUrl: repository.url.trim(),
      branchPresent: true,
      branchPath: (b != null && b.isNotEmpty) ? b : '',
      commitPresent: focusCommitRevision != null,
      commitRevision: focusCommitRevision,
    );
  }

  factory PersistedChatScope.fromJson(Map<String, dynamic> json) {
    return PersistedChatScope(
      svnPresent: json.containsKey('svn'),
      svnUrl: json['svn'] as String?,
      branchPresent: json.containsKey('branch'),
      branchPath: json['branch'] as String?,
      commitPresent: json.containsKey('commit'),
      commitRevision: json['commit'] != null
          ? (json['commit'] as num).toInt()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{};
    if (svnPresent) m['svn'] = svnUrl;
    if (branchPresent) m['branch'] = branchPath;
    if (commitPresent) m['commit'] = commitRevision;
    return m;
  }
}

class ChatSession {
  ChatSession({
    required this.id,
    required this.repoName,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.chatScope,
  });

  final String id;
  final String repoName;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Each entry: `{'role': 'user'|'assistant', 'content': '...'}`.
  final List<Map<String, String>> messages;

  /// 非 null 表示檔內含 `chat_scope`（新格式）；null 為舊檔僅有 messages。
  final PersistedChatScope? chatScope;

  ChatSession copyWith({
    DateTime? updatedAt,
    List<Map<String, String>>? messages,
    PersistedChatScope? chatScope,
  }) =>
      ChatSession(
        id: id,
        repoName: repoName,
        title: title,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        messages: messages ?? this.messages,
        chatScope: chatScope ?? this.chatScope,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'repo_name': repoName,
        'title': title,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'messages': messages,
        if (chatScope != null) 'chat_scope': chatScope!.toJson(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'] as String,
        repoName: json['repo_name'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
        messages: (json['messages'] as List)
            .map((m) => Map<String, String>.from(m as Map))
            .toList(),
        chatScope: json['chat_scope'] is Map<String, dynamic>
            ? PersistedChatScope.fromJson(
                Map<String, dynamic>.from(json['chat_scope'] as Map),
              )
            : null,
      );

  /// Derives a display title from the first user message.
  static String titleFromFirstMessage(String firstUserMessage) {
    final trimmed = firstUserMessage.trim().replaceAll('\n', ' ');
    return trimmed.length > 60 ? '${trimmed.substring(0, 60)}…' : trimmed;
  }

  /// Generates a unique session ID based on timestamp and repo name prefix.
  static String generateId(String repoName) {
    final now = DateTime.now();
    final ts =
        '${now.year}${_pad(now.month)}${_pad(now.day)}_${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';
    final prefix = repoName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final safe = prefix.length > 12 ? prefix.substring(0, 12) : prefix;
    return '${ts}_$safe';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}
