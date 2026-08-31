import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/mom_tokens.dart';
import '../../core/theme/mom_typography.dart';
import '../../core/widgets/primary_button.dart';

/// Full-page celebration shown right after checking off a habit pushes
/// its streak to a new number — on top of the streak count already
/// shown on the task card, this is the "moment" version of the same
/// fact. Dismisses itself on tap or after a few seconds.
Future<void> showStreakCelebration(
  BuildContext context, {
  required String taskTitle,
  required int streakCount,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, _) => FadeTransition(
        opacity: animation,
        child: _StreakCelebrationScreen(taskTitle: taskTitle, streakCount: streakCount),
      ),
    ),
  );
}

class _StreakCelebrationScreen extends StatefulWidget {
  const _StreakCelebrationScreen({required this.taskTitle, required this.streakCount});
  final String taskTitle;
  final int streakCount;

  @override
  State<_StreakCelebrationScreen> createState() => _StreakCelebrationScreenState();
}

class _StreakCelebrationScreenState extends State<_StreakCelebrationScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  String get _line {
    final n = widget.streakCount;
    if (n >= 30) return "A month deep. That's not a habit anymore, that's just who you are.";
    if (n >= 14) return "Two weeks strong. I'm genuinely proud of you.";
    if (n >= 7) return "A full week. Look at you go.";
    if (n >= 3) return "Building something real here.";
    return "That's a start — keep it up.";
  }

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Container(
            margin: const EdgeInsets.all(AppSpacing.xl),
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: mom.surface,
              borderRadius: BorderRadius.circular(AppSpacing.momRadiusSheet),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: mom.doneOrange),
                  alignment: Alignment.center,
                  child: const Icon(LucideIcons.flame, color: Colors.white, size: 36),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '${widget.streakCount} day streak',
                  style: MomText.screenTitle(mom.ink),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.taskTitle,
                  style: MomText.body(mom.inkSoft),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _line,
                  style: MomText.body(mom.ink),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: 'Keep going',
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
