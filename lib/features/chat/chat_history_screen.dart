import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers/service_providers.dart';
import '../../core/repositories/chat_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Full conversation history — every past chat session, listed newest
/// first, tap to reopen. Mirrors Claude's own "recents" pattern.
/// Pops with the tapped session's id.
class ChatHistoryScreen extends ConsumerWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userId = ref.watch(supabaseClientProvider).auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Recents')),
      body: userId == null
          ? const SizedBox.shrink()
          : FutureBuilder<List<ChatSessionSummary>>(
              future: ref.read(chatRepositoryProvider).fetchSessions(userId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                }
                final sessions = snapshot.data!;
                if (sessions.isEmpty) {
                  return Center(
                    child: Text('No conversations yet.', style: theme.textTheme.bodySmall),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: sessions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final s = sessions[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusRow),
                      onTap: () => Navigator.of(context).pop(s.id),
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
                                s.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            Text(DateFormat('MMM d').format(s.lastMessageAt), style: theme.textTheme.labelSmall),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
