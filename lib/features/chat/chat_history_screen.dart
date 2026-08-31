import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers/service_providers.dart';
import '../../core/repositories/chat_repository.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/mom_tokens.dart';
import '../../core/theme/mom_typography.dart';
import '../../core/utils/friendly_error.dart';

/// Full conversation history — every past chat session, listed newest
/// first, tap to reopen. Mirrors Claude's own "recents" pattern.
/// Pops with the tapped session's id.
class ChatHistoryScreen extends ConsumerWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mom = context.mom;
    final sessionsAsync = ref.watch(chatSessionsProvider);

    return Scaffold(
      backgroundColor: mom.shell,
      appBar: AppBar(
        backgroundColor: mom.shell,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, size: 22, color: mom.espresso),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Recents', style: MomText.cardTitle(mom.ink)),
      ),
      body: sessionsAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: mom.espresso)),
        error: (e, _) => Center(child: Text(friendlyError(e), style: MomText.body(mom.inkMuted))),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  "No conversations yet. Say something to Mom and it'll show up here.",
                  textAlign: TextAlign.center,
                  style: MomText.body(mom.inkMuted),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(AppSpacing.momGutter, AppSpacing.sm, AppSpacing.momGutter, AppSpacing.xl),
            itemCount: sessions.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.momRowGap),
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
    final mom = context.mom;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this conversation?'),
        content: Text('"${session.title}" and its messages will be gone for good.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: mom.danger)),
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
    final mom = context.mom;
    return Slidable(
      key: ValueKey(session.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (actionContext) => _confirmAndDelete(actionContext, ref),
            backgroundColor: mom.danger,
            foregroundColor: Colors.white,
            icon: LucideIcons.trash2,
            borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard),
        onTap: () => Navigator.of(context).pop(session.id),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: mom.surface,
            borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard),
            boxShadow: MomElevation.card,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MomText.rowLabel(mom.ink),
                ),
              ),
              Text(DateFormat('MMM d').format(session.lastMessageAt), style: MomText.meta(mom.inkMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
