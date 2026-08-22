import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers/app_state_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/mom_avatar.dart';
import '../../core/widgets/primary_button.dart';

/// Onboarding answers are collected here and feed the backend fields that
/// personalize Mom's chat context and notification cadence once wired up.
class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key});

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

const _goalOptions = ['Get more done', 'Build habits', 'Spend less', 'Get healthier'];
const _procrastinationOptions = ['Exercise', 'Chores', 'Work deadlines', 'Sleeping on time', 'Spending less'];
const _frequencyOptions = ['A few times a day', 'Once a day', 'A few times a week'];

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _pageController = PageController();
  int _step = 0;
  final _nameController = TextEditingController();
  final _goals = <String>{};
  final _procrastination = <String>{};
  String _frequency = _frequencyOptions.first;

  static const _totalSteps = 6;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == _totalSteps - 1) {
      if (_nameController.text.trim().isNotEmpty) {
        ref.read(userNameProvider.notifier).state = _nameController.text.trim();
      }
      context.go('/dashboard');
      return;
    }
    setState(() => _step++);
    _pageController.animateToPage(
      _step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  bool get _canContinue => switch (_step) {
        1 => _nameController.text.trim().isNotEmpty,
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              child: Row(
                children: [
                  for (var i = 0; i < _totalSteps; i++)
                    Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: i == _totalSteps - 1 ? 0 : AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: i <= _step ? AppColors.accent : theme.dividerTheme.color,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _AvatarStep(),
                  _NameStep(controller: _nameController, onChanged: () => setState(() {})),
                  _MultiSelectStep(
                    title: "What are you here to work on?",
                    subtitle: 'Pick as many as apply.',
                    options: _goalOptions,
                    selected: _goals,
                    onToggle: (o) => setState(() => _goals.contains(o) ? _goals.remove(o) : _goals.add(o)),
                  ),
                  _MultiSelectStep(
                    title: 'What do you tend to put off?',
                    subtitle: "Mom's starting with these.",
                    options: _procrastinationOptions,
                    selected: _procrastination,
                    onToggle: (o) => setState(
                        () => _procrastination.contains(o) ? _procrastination.remove(o) : _procrastination.add(o)),
                  ),
                  _FrequencyStep(
                    selected: _frequency,
                    onSelect: (f) => setState(() => _frequency = f),
                  ),
                  const _AuthStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
              child: PrimaryButton(
                label: _step == _totalSteps - 1 ? 'Create account' : 'Continue',
                onPressed: _canContinue ? _next : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({required this.title, this.subtitle, required this.child});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineLarge),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle!, style: theme.textTheme.titleSmall),
          ],
          const SizedBox(height: AppSpacing.xl),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AvatarStep extends ConsumerWidget {
  const _AvatarStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(momAvatarStyleProvider);
    return _StepScaffold(
      title: 'Meet your Mom',
      subtitle: 'Pick a look. She is still Mom either way.',
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: AppSpacing.lg,
        crossAxisSpacing: AppSpacing.lg,
        children: [
          for (final style in MomAvatarStyle.values)
            GestureDetector(
              onTap: () => ref.read(momAvatarStyleProvider.notifier).state = style,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected == style ? AppColors.accent : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: MomAvatar(style: style, showMoodBadge: false, size: 56),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StepScaffold(
      title: 'What should Mom call you?',
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: 'Your name',
          filled: true,
          fillColor: theme.cardTheme.color,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusRow),
            borderSide: BorderSide(color: theme.dividerTheme.color ?? AppColors.borderLight),
          ),
        ),
      ),
    );
  }
}

class _MultiSelectStep extends StatelessWidget {
  const _MultiSelectStep({
    required this.title,
    this.subtitle,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  final String title;
  final String? subtitle;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: title,
      subtitle: subtitle,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final o in options)
            _ChoiceCard(label: o, selected: selected.contains(o), onTap: () => onToggle(o)),
        ],
      ),
    );
  }
}

class _FrequencyStep extends StatelessWidget {
  const _FrequencyStep({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'How often should Mom check in?',
      subtitle: 'You can change this later in Settings.',
      child: Column(
        children: [
          for (final f in _frequencyOptions)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ChoiceCard(
                label: f,
                selected: selected == f,
                onTap: () => onSelect(f),
                fullWidth: true,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.label,
    required this.selected,
    required this.onTap,
    this.fullWidth = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: selected ? theme.colorScheme.secondary : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(AppSpacing.radiusRow),
        border: Border.all(
          color: selected ? theme.colorScheme.secondary : (theme.dividerTheme.color ?? AppColors.borderLight),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: selected ? theme.colorScheme.onSecondary : theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: fullWidth ? SizedBox(width: double.infinity, child: content) : content,
    );
  }
}

class _AuthStep extends StatelessWidget {
  const _AuthStep();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StepScaffold(
      title: 'Create your account',
      subtitle: "Save your Mom and pick up where you left off.",
      child: Column(
        children: [
          _AuthButton(icon: LucideIcons.mail, label: 'Continue with email'),
          const SizedBox(height: AppSpacing.sm),
          _AuthButton(icon: LucideIcons.globe, label: 'Continue with Google'),
          const SizedBox(height: AppSpacing.sm),
          _AuthButton(icon: LucideIcons.apple, label: 'Continue with Apple'),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'By continuing you agree to the Terms of Service and Privacy Policy.',
            style: theme.textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurface,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          side: BorderSide(color: theme.dividerTheme.color ?? AppColors.borderLight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
        ),
      ),
    );
  }
}
