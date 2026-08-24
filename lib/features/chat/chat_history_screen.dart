import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers/service_providers.dart';
import '../../core/repositories/chat_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/friendly_error.dart';

/// Full conversation history — every past chat session, listed newest
/// first, tap to reopen. Mirrors Claude's own "recents" pattern.
/// Pops with the tapped session's id.
class ChatHistoryScreen extends ConsumerWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessionsAsync = ref.watch(chatSessionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recents')),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(child: Text(friendlyError(e), style: theme.textTheme.bodySmall)),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  "No conversations yet. Say something to Mom and it'll show up here.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: sessions.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) => _SessionRow(session: sessions[i]),
          );
        },
      ),
    );
  }
}

class _SessionRow extends ConsumerWidget {
  const _SessionRow({required this.session});
  final ChatSessionSummary session;

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this conversation?'),
        content: Text('"${session.title}" and its messages will be gone for good.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.moodDisappointed)),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      if (context.mounted) Slidable.of(context)?.close();
      return;
    }
    try {
      await ref.read(chatRepositoryProvider).deleteSession(session.id);
      ref.invalidate(chatSessionsProvider);
    } catch (e) {
      if (context.mounted) {
        Slidable.of(context)?.close();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Slidable(
      key: ValueKey(session.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (actionContext) => _confirmAndDelete(actionContext, ref),
            backgroundColor: AppColors.moodDisappointed,
            foregroundColor: Colors.white,
            icon: LucideIcons.trash2,
            borderRadius: BorderRadius.circular(AppSpacing.radiusRow),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusRow),
        onTap: () => Navigator.of(context).pop(session.id),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(AppSpacing.radiusRow),
            border: Border.all(color: theme.dividerTheme.color ?? AppColors.borderLight),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(DateFormat('MMM d').format(session.lastMessageAt), style: theme.textTheme.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}
