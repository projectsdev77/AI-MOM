import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/plan.dart';
import '../../core/providers/app_state_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/mom_avatar.dart';
import 'chat_history_screen.dart';

class ChatMessage {
  const ChatMessage({required this.fromMom, required this.text});
  final bool fromMom;
  final String text;
}

final chatMessagesProvider = StateProvider<List<ChatMessage>>((ref) => const [
      ChatMessage(
        fromMom: true,
        text: "Morning. I saw yesterday's task list. We are not doing that again, right?",
      ),
      ChatMessage(fromMom: false, text: "I'll do better today, promise."),
      ChatMessage(
        fromMom: true,
        text: 'Mm-hm. I have heard that one before. Go drink some water, then talk to me.',
      ),
    ]);

/// Messages sent this week, for the Basic-tier weekly cap.
final weeklyMessageCountProvider = StateProvider<int>((ref) => 9);

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final plan = ref.read(planProvider);
    if (!plan.isFull &&
        ref.read(weeklyMessageCountProvider) >= plan.weeklyChatMessageLimit) {
      return;
    }
    ref.read(chatMessagesProvider.notifier).update((m) => [
          ...m,
          ChatMessage(fromMom: false, text: text),
        ]);
    if (!plan.isFull) {
      ref.read(weeklyMessageCountProvider.notifier).update((c) => c + 1);
    }
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messages = ref.watch(chatMessagesProvider);
    final plan = ref.watch(planProvider);
    final momAvatar = ref.watch(momAvatarStyleProvider);
    final weeklyUsed = ref.watch(weeklyMessageCountProvider);
    final atLimit = !plan.isFull && weeklyUsed >= plan.weeklyChatMessageLimit;

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
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChatHistoryScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!plan.isFull)
            Container(
              width: double.infinity,
              color: AppColors.chipPeach,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                atLimit
                    ? "You're out of chat messages for this week. Full Mom is 24/7."
                    : '${plan.weeklyChatMessageLimit - weeklyUsed} messages left with Mom this week.',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textPrimaryLight),
              ),
            ),
          Expanded(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final m = messages[messages.length - 1 - index];
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
                        m.text,
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !atLimit,
                      decoration: InputDecoration(
                        hintText: atLimit ? 'Come back next week' : 'Talk to Mom...',
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
                    onPressed: atLimit ? null : _send,
                    icon: const Icon(LucideIcons.arrowUp, color: Colors.white),
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
