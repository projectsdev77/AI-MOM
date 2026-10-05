import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/constants/onboarding_options.dart';
import '../../core/providers/service_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/mom_tokens.dart';
import '../../core/theme/mom_typography.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/widgets/mom_components.dart';
import '../../core/widgets/primary_button.dart';

/// Every onboarding question past the ones already editable elsewhere
/// in Settings (name, avatar, check-in frequency) — goals, what you
/// procrastinate on, daily routine, living situation, motivation
/// style, and current stressor. These feed Mom's chat system prompt
/// (see supabase/functions/mom-chat), but were only ever askable once,
/// at onboarding, with no way back in if an answer changed or was
/// skipped. Reuses onboarding's own option lists (core/constants/
/// onboarding_options.dart) and the same MomChip/MomOptionRow pieces
/// it uses, so picking an answer here looks identical to picking it
/// there — just without onboarding's one-question-per-page pacing or
/// Mom's reaction bubbles, since this is a plain edit form, not a
/// first-impression flow.
class OnboardingAnswersScreen extends ConsumerWidget {
  const OnboardingAnswersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mom = context.mom;
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: mom.shell,
      appBar: AppBar(
        backgroundColor: mom.shell,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft, size: 22, color: mom.espresso),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Your answers', style: MomText.cardTitle(mom.ink)),
      ),
      body: profileAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: mom.espresso)),
        error: (e, _) => Center(child: Text(friendlyError(e), style: MomText.body(mom.inkMuted))),
        data: (profile) => _AnswersForm(profile: profile ?? const {}),
      ),
    );
  }
}

class _AnswersForm extends ConsumerStatefulWidget {
  const _AnswersForm({required this.profile});
  final Map<String, dynamic> profile;

  @override
  ConsumerState<_AnswersForm> createState() => _AnswersFormState();
}

class _AnswersFormState extends ConsumerState<_AnswersForm> {
  late final _goals = <String>{...?(widget.profile['goals'] as List?)?.cast<String>()};
  late final _procrastination = <String>{...?(widget.profile['procrastination_areas'] as List?)?.cast<String>()};
  late String? _dailyRoutine = widget.profile['daily_routine'] as String?;
  late String? _livingSituation = widget.profile['living_situation'] as String?;
  late String? _motivationStyle = widget.profile['motivation_style'] as String?;
  late final _stressorController = TextEditingController(text: widget.profile['current_stressor'] as String? ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _stressorController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateOnboardingExtras(
            userId: userId,
            goals: _goals.toList(),
            procrastinationAreas: _procrastination.toList(),
            dailyRoutine: _dailyRoutine,
            livingSituation: _livingSituation,
            motivationStyle: _motivationStyle,
            currentStressor: _stressorController.text,
          );
      ref.invalidate(profileProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.momGutter, AppSpacing.sm, AppSpacing.momGutter, AppSpacing.xxl),
      children: [
        Text(
          "These shape how Mom talks to you in chat. Change whatever's out of date.",
          style: MomText.body(mom.inkMuted),
        ),
        const SizedBox(height: AppSpacing.momSectionGap),
        _Section(
          title: 'What are you hoping to get done?',
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final o in goalOptions)
                MomChip(
                  label: o,
                  selected: _goals.contains(o),
                  onTap: () => setState(() => _goals.contains(o) ? _goals.remove(o) : _goals.add(o)),
                ),
            ],
          ),
        ),
        _Section(
          title: 'What do you tend to put off?',
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final o in procrastinationOptions)
                MomChip(
                  label: o,
                  selected: _procrastination.contains(o),
                  onTap: () => setState(
                      () => _procrastination.contains(o) ? _procrastination.remove(o) : _procrastination.add(o)),
                ),
            ],
          ),
        ),
        _Section(
          title: "What's your daily routine like?",
          child: Column(
            children: [
              for (var i = 0; i < dailyRoutineOptions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.momRowGap),
                  child: MomOptionRow(
                    label: dailyRoutineOptions[i],
                    sub: dailyRoutineSubs[i],
                    selected: _dailyRoutine == dailyRoutineOptions[i],
                    onTap: () => setState(() => _dailyRoutine = dailyRoutineOptions[i]),
                  ),
                ),
            ],
          ),
        ),
        _Section(
          title: "What's your living situation?",
          child: Column(
            children: [
              for (var i = 0; i < livingSituationOptions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.momRowGap),
                  child: MomOptionRow(
                    label: livingSituationOptions[i],
                    sub: livingSituationSubs[i],
                    selected: _livingSituation == livingSituationOptions[i],
                    onTap: () => setState(() => _livingSituation = livingSituationOptions[i]),
                  ),
                ),
            ],
          ),
        ),
        _Section(
          title: 'What motivates you best?',
          child: Column(
            children: [
              for (var i = 0; i < motivationStyleOptions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.momRowGap),
                  child: MomOptionRow(
                    label: motivationStyleOptions[i],
                    sub: motivationStyleSubs[i],
                    selected: _motivationStyle == motivationStyleOptions[i],
                    onTap: () => setState(() => _motivationStyle = motivationStyleOptions[i]),
                  ),
                ),
            ],
          ),
        ),
        _Section(
          title: "What's stressing you out lately?",
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            constraints: const BoxConstraints(minHeight: 110),
            decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _stressorController,
                  onChanged: (_) => setState(() {}),
                  maxLines: 4,
                  maxLength: 200,
                  textCapitalization: TextCapitalization.sentences,
                  style: MomText.body(mom.ink).copyWith(fontSize: 14),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    counterText: '',
                    hintText: 'Work deadlines, money, a big life change…',
                    hintStyle: MomText.placeholder(mom.placeholderText),
                  ),
                ),
                Text('${_stressorController.text.length} / 200', style: MomText.meta(mom.placeholderText, size: 11)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: _saving ? 'Saving…' : 'Save changes',
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.momSectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: MomText.section(mom.ink)),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}
