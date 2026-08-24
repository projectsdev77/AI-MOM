import 'package:supabase_flutter/supabase_flutter.dart';

class ChatSessionSummary {
  const ChatSessionSummary({required this.id, required this.title, required this.lastMessageAt});
  final String id;
  final String title;
  final DateTime lastMessageAt;
}

class ChatMessageRow {
  const ChatMessageRow({required this.fromMom, required this.content});
  final bool fromMom;
  final String content;
}

/// Thrown when the mom-chat edge function reports the Basic-tier weekly
/// message cap has been hit (HTTP 402 from the function).
class WeeklyChatLimitReached implements Exception {}

class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  Future<List<ChatSessionSummary>> fetchSessions(String userId) async {
    final rows = await _client
        .from('chat_sessions')
        .select()
        .eq('user_id', userId)
        .order('last_message_at', ascending: false);
    return [
      for (final row in rows)
        ChatSessionSummary(
          id: row['id'] as String,
          title: row['title'] as String,
          lastMessageAt: DateTime.parse(row['last_message_at'] as String),
        ),
    ];
  }

  /// Messages cascade-delete with the session (see the
  /// `on delete cascade` foreign key in migrations/0001_init.sql).
  Future<void> deleteSession(String sessionId) {
    return _client.from('chat_sessions').delete().eq('id', sessionId);
  }

  Future<List<ChatMessageRow>> fetchMessages(String sessionId) async {
    final rows = await _client
        .from('chat_messages')
        .select('from_mom, content')
        .eq('session_id', sessionId)
        .order('created_at');
    return [
      for (final row in rows)
        ChatMessageRow(fromMom: row['from_mom'] as bool, content: row['content'] as String),
    ];
  }

  /// Sends a message through the mom-chat edge function, which handles
  /// the Claude call, weekly-cap enforcement, and persisting both sides
  /// of the exchange. Returns the (possibly newly created) session id,
  /// Mom's reply, and how many Basic-tier messages remain this week
  /// (null on the Full plan, where there's no cap).
  Future<({String sessionId, String reply, int? remainingThisWeek})> sendMessage({
    String? sessionId,
    required String message,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'mom-chat',
        body: {if (sessionId != null) 'sessionId': sessionId, 'message': message},
      );
      final data = response.data as Map<String, dynamic>;
      return (
        sessionId: data['sessionId'] as String,
        reply: data['reply'] as String,
        remainingThisWeek: data['remainingThisWeek'] as int?,
      );
    } on FunctionException catch (e) {
      if (e.status == 402) throw WeeklyChatLimitReached();
      rethrow;
    }
  }
}
