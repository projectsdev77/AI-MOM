import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class _Session {
  const _Session(this.title, this.preview, this.date);
  final String title;
  final String preview;
  final String date;
}

const _sessions = [
  _Session('Overdue report', "Mom, I know, I know...", 'Today'),
  _Session('Sunday check-in', 'Weekly wrap-up with Mom', 'Sun'),
  _Session('Water reminder pushback', "I'm drinking coffee, does that count?", 'Fri'),
];

/// Full conversation history — every past chat session, listed newest
/// first, tap to reopen. Mirrors Claude's own "recents" pattern.
class ChatHistoryScreen extends StatelessWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Recents')),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: _sessions.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, i) {
          final s = _sessions[i];
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(AppSpacing.radiusRow),
              border: Border.all(color: theme.dividerTheme.color ?? AppColors.borderLight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        s.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(s.date, style: theme.textTheme.labelSmall),
              ],
            ),
          );
        },
      ),
    );
  }
}
