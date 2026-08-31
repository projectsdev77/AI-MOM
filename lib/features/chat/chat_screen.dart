import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/models/plan.dart';
import '../../core/providers/app_state_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/track_providers.dart';
import '../../core/repositories/chat_repository.dart';
import '../../core/repositories/health_repository.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/mom_mood.dart';
import '../../core/theme/mom_tokens.dart';
import '../../core/theme/mom_typography.dart';
import '../../core/widgets/mom_avatar.dart';
import '../../core/widgets/mom_components.dart';

const _suggestions = [
  'How am I doing today?',
  'What should I focus on?',
  'Any wins to celebrate?',
];

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

  void _startNewChat() {
    setState(() {
      _sessionId = null;
      _messages.clear();
      _error = null;
      _atWeeklyLimit = false;
    });
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

  Future<void> _send([String? text]) async {
    final message = (text ?? _controller.text).trim();
    if (message.isEmpty || _sending || _atWeeklyLimit) return;

    setState(() {
      _sending = true;
      _error = null;
      _messages.add(ChatMessageRow(fromMom: false, content: message));
    });
    _controller.clear();

    try {
      final result = await ref.read(chatRepositoryProvider).sendMessage(
            sessionId: _sessionId,
            message: message,
          );
      setState(() {
        _sessionId = result.sessionId;
        _messages.add(ChatMessageRow(fromMom: true, content: result.reply));
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
    final mom = context.mom;
    final momAvatar = ref.watch(effectiveMomAvatarProvider);

    return Scaffold(
      body: Column(
        children: [
          _ChatHeader(
            avatarStyle: momAvatar,
            onNewChat: _startNewChat,
            onHistory: () async {
              final selected = await context.push<String>('/chat/history');
              if (selected != null && selected != _sessionId) {
                setState(() => _sessionId = selected);
                _loadHistory(selected);
              }
            },
          ),
          if (_atWeeklyLimit)
            Container(
              width: double.infinity,
              color: mom.promoPeach,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.momGutter, vertical: AppSpacing.sm),
              child: Text("You're out of chat messages for this week. Full Mom is 24/7.", style: MomText.body(mom.ink)),
            ),
          Expanded(
            child: _loadingHistory
                ? Center(child: CircularProgressIndicator(color: mom.espresso))
                : _messages.isEmpty
                    ? _ChatEmptyState(avatarStyle: momAvatar, onSuggestionTap: _send)
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(AppSpacing.momGutter),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final m = _messages[_messages.length - 1 - index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Align(
                              alignment: m.fromMom ? Alignment.centerLeft : Alignment.centerRight,
                              child: Container(
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: m.fromMom ? mom.surface : mom.espresso,
                                  borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard),
                                  boxShadow: m.fromMom ? MomElevation.card : null,
                                ),
                                child: Text(m.content, style: MomText.body(m.fromMom ? mom.ink : Colors.white)),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.momGutter),
              child: Text(_error!, style: MomText.meta(mom.danger)),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.momGutter, AppSpacing.sm, AppSpacing.momGutter, AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      enabled: !_atWeeklyLimit && !_sending,
                      style: MomText.body(mom.ink),
                      decoration: InputDecoration(
                        hintText: _atWeeklyLimit ? 'Come back next week' : 'Talk to Mom…',
                        hintStyle: MomText.placeholder(mom.placeholderText),
                        filled: true,
                        fillColor: mom.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.momGutter, vertical: AppSpacing.md),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  GestureDetector(
                    onTap: (_atWeeklyLimit || _sending) ? null : () => _send(),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (_atWeeklyLimit || _sending) ? mom.espresso.withValues(alpha: 0.4) : mom.espresso,
                      ),
                      alignment: Alignment.center,
                      child: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(LucideIcons.arrowUp, color: Colors.white, size: 22),
                    ),
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

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.avatarStyle, required this.onNewChat, required this.onHistory});
  final MomAvatarStyle avatarStyle;
  final VoidCallback onNewChat;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return Container(
      decoration: BoxDecoration(
        color: mom.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppSpacing.momRadiusPanel)),
        boxShadow: MomElevation.card,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.momGutter, AppSpacing.sm, AppSpacing.sm, AppSpacing.md),
          child: Row(
            children: [
              MomAvatar(style: avatarStyle, expression: MomExpression.happy, showMoodBadge: false, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Mom', style: MomText.cardTitle(mom.ink)),
                    Text('Checks in a few times a day', style: MomText.rowSub(mom.inkMuted)),
                  ],
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  icon: Icon(LucideIcons.plus, color: mom.inkSoft),
                  tooltip: 'New chat',
                  onPressed: onNewChat,
                ),
              ),
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  icon: Icon(LucideIcons.history, color: mom.inkSoft),
                  tooltip: 'Recents',
                  onPressed: onHistory,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatEmptyState extends ConsumerWidget {
  const _ChatEmptyState({required this.avatarStyle, required this.onSuggestionTap});
  final MomAvatarStyle avatarStyle;
  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mom = context.mom;
    final plan = ref.watch(planProvider);
    final tasks = ref.watch(tasksProvider);
    final openTask = tasks.where((t) => !t.done).isEmpty ? null : tasks.firstWhere((t) => !t.done);
    final healthToday = ref.watch(healthTodayProvider).valueOrNull;
    final healthGoals = ref.watch(healthGoalsProvider).valueOrNull;

    final unloggedMetric = _firstUnloggedMetric(healthToday, healthGoals);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.momGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MomMessageCard(
            avatarStyle: avatarStyle,
            expression: MomExpression.happy,
            eyebrow: "Say hi",
            message: 'Say something to Mom to get started. I read everything you send — even the little stuff.',
          ),
          const SizedBox(height: AppSpacing.momSectionGap),
          Text('Try asking', style: MomText.section(mom.ink)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.momRowGap,
            runSpacing: AppSpacing.momRowGap,
            children: [for (final s in _suggestions) MomChip(label: s, selected: false, onTap: () => onSuggestionTap(s))],
          ),
          if (openTask != null || unloggedMetric != null) ...[
            const SizedBox(height: AppSpacing.momSectionGap),
            Text("On Mom's mind", style: MomText.section(mom.ink)),
            const SizedBox(height: AppSpacing.sm),
            Container(
              decoration: BoxDecoration(
                color: mom.surface,
                borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard),
                boxShadow: MomElevation.card,
              ),
              child: Column(
                children: [
                  if (openTask != null)
                    _OnMindRow(
                      icon: LucideIcons.listChecks,
                      tintIndex: 0,
                      title: openTask.title,
                      sub: openTask.dueTimeLabel ?? openTask.categoryLabel,
                      onTap: () => context.go('/tasks'),
                    ),
                  if (openTask != null && unloggedMetric != null) Divider(height: 1, color: mom.hairline),
                  if (unloggedMetric != null)
                    _OnMindRow(
                      icon: LucideIcons.droplets,
                      tintIndex: 4,
                      title: unloggedMetric,
                      sub: "Nothing logged today",
                      onTap: () => context.push(plan.isFull ? '/track/health' : '/upgrade'),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _firstUnloggedMetric(HealthToday? today, HealthGoals? goals) {
    if (goals == null) return null;
    if ((today?.waterCount ?? 0) == 0) return 'Water';
    if (today?.sleepHours == null) return 'Sleep';
    if ((today?.workoutMinutes ?? 0) == 0) return 'Exercise';
    return null;
  }
}

class _OnMindRow extends StatelessWidget {
  const _OnMindRow({required this.icon, required this.tintIndex, required this.title, required this.sub, required this.onTap});
  final IconData icon;
  final int tintIndex;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final tint = mom.tints[tintIndex % mom.tints.length];
    final tintIcon = mom.tintIcons[tintIndex % mom.tintIcons.length];
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(AppSpacing.momRadiusTile)),
              child: Icon(icon, size: 17, color: tintIcon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: MomText.rowLabel(mom.ink)),
                  Text(sub, style: MomText.rowSub(mom.inkMuted)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: mom.inkMuted),
          ],
        ),
      ),
    );
  }
}
