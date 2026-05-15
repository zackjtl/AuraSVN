import 'dart:convert';
import 'dart:io';

import 'package:aura_svn/models/chat_session.dart';
import 'package:aura_svn/utils/path_utils.dart';

/// Persists chat sessions under:
///   `{parent of notesRootPath}/chat_history/{repoName}/{sessionId}.json`
class ChatHistoryStore {
  ChatHistoryStore._();

  static Directory _dir(String notesRootPath, String repoName) {
    final parent = Directory(notesRootPath).parent.path;
    return Directory(joinPath(parent, 'chat_history', repoName));
  }

  static File _file(String notesRootPath, ChatSession session) => File(
        joinPath(
          _dir(notesRootPath, session.repoName).path,
          '${session.id}.json',
        ),
      );

  static Future<void> save(ChatSession session, String notesRootPath) async {
    final dir = _dir(notesRootPath, session.repoName);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    await _file(notesRootPath, session).writeAsString(
      const JsonEncoder.withIndent('  ').convert(session.toJson()),
      encoding: utf8,
    );
  }

  static Future<List<ChatSession>> list(
      String notesRootPath, String repoName) async {
    final dir = _dir(notesRootPath, repoName);
    if (!dir.existsSync()) return [];
    final sessions = <ChatSession>[];
    for (final entity in dir.listSync()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final raw = await entity.readAsString(encoding: utf8);
          sessions.add(ChatSession.fromJson(
              jsonDecode(raw) as Map<String, dynamic>));
        } catch (_) {
          // skip corrupt files
        }
      }
    }
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions;
  }

  static Future<void> delete(ChatSession session, String notesRootPath) async {
    final f = _file(notesRootPath, session);
    if (f.existsSync()) await f.delete();
  }
}
