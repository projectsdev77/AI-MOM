import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers/app_state_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/repositories/chat_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/mom_avatar.dart';
import 'chat_history_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, this.initialSessionId});

  final String? initialSessionId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _messages = <ChatMessageRow>[];
  String? _sessionId;
  bool _loadingHistory = false;
  bool _sending = false;
  int? _remainingThisWeek;
  bool _atWeeklyLimit = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sessionId = widget.initialSessionId;
    if (_sessionId != null) _loadHistory(_sessionId!);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadHistory(String sessionId) async {
    setState(() => _loadingHistory = true);
    try {
      final rows = await ref.read(chatRepositoryProvider).fetchMessages(sessionId);
      setState(() => _messages
        ..clear()
        ..addAll(rows));
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending || _atWeeklyLimit) return;

    setState(() {
      _sending = true;
      _error = null;
      _messages.add(ChatMessageRow(fromMom: false, content: text));
    });
    _controller.clear();

    try {
      final result = await ref.read(chatRepositoryProvider).sendMessage(
            sessionId: _sessionId,
            message: text,
          );
      setState(() {
        _sessionId = result.sessionId;
        _messages.add(ChatMessageRow(fromMom: true, content: result.reply));
        _remainingThisWeek = result.remainingThisWeek;
        _atWeeklyLimit = (result.remainingThisWeek ?? 1) < 0;
      });
    } on WeeklyChatLimitReached {
      setState(() {
        _atWeeklyLimit = true;
        _messages.removeLast(); // the message was never sent server-side
      });
    } catch (e) {
      setState(() {
        _error = "Mom didn't answer. Try again in a moment.";
        _messages.removeLast();
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final momAvatar = ref.watch(effectiveMomAvatarProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            MomAvatar(style: momAvatar, size: 32, showMoodBadge: false),
            const SizedBox(width: AppSpacing.sm),
            const Text('Mom'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.history),
            tooltip: 'Recents',
            onPressed: () async {
              final selected = await Navigator.of(context).push<String>(
                MaterialPageRoute(builder: (_) => const ChatHistoryScreen()),
              );
              if (selected != null && selected != _sessionId) {
                setState(() => _sessionId = selected);
                _loadHistory(selected);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_remainingThisWeek != null && !_atWeeklyLimit)
            Container(
              width: double.infinity,
              color: AppColors.chipPeach,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                '${_remainingThisWeek! + 1} messages left with Mom this week.',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textPrimaryLight),
              ),
            ),
          if (_atWeeklyLimit)
            Container(
              width: double.infinity,
              color: AppColors.chipPeach,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                "You're out of chat messages for this week. Full Mom is 24/7.",
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textPrimaryLight),
              ),
            ),
          Expanded(
            child: _loadingHistory
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'Say something to Mom to get started.',
                          style: theme.textTheme.bodySmall,
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final m = _messages[_messages.length - 1 - index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Align(
                              alignment: m.fromMom ? Alignment.centerLeft : Alignment.centerRight,
                              child: Container(
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: m.fromMom ? theme.cardTheme.color : AppColors.accent,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
                                  border: m.fromMom
                                      ? Border.all(color: theme.dividerTheme.color ?? AppColors.borderLight)
                                      : null,
                                ),
                                child: Text(
                                  m.content,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: m.fromMom ? null : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.moodDisappointed)),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_atWeeklyLimit && !_sending,
                      decoration: InputDecoration(
                        hintText: _atWeeklyLimit ? 'Come back next week' : 'Talk to Mom...',
                        filled: true,
                        fillColor: theme.cardTheme.color,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                          borderSide: BorderSide(color: theme.dividerTheme.color ?? AppColors.borderLight),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppColors.accent),
                    onPressed: (_atWeeklyLimit || _sending) ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(LucideIcons.arrowUp, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
