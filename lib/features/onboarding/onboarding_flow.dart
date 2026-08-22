import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers/app_state_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/mom_avatar.dart';
import '../../core/widgets/primary_button.dart';

/// Onboarding answers are collected here, then written to `profiles`
/// once the account is created — see [_OnboardingFlowState._submit].
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _goals = <String>{};
  final _procrastination = <String>{};
  String _frequency = _frequencyOptions.first;
  bool _submitting = false;
  String? _error;

  static const _totalSteps = 6;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    setState(() => _step = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final auth = ref.read(authServiceProvider);
      await auth.signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
      );
      await _saveOnboardingAnswers();
      // The router's auth-state listener takes it from here and redirects
      // to /dashboard once the session is set.
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _saveOnboardingAnswers() async {
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return;
    await ref.read(profileRepositoryProvider).saveOnboardingAnswers(
          userId: userId,
          momAvatarStyle: ref.read(momAvatarStyleProvider).name,
          goals: _goals.toList(),
          procrastinationAreas: _procrastination.toList(),
          checkInFrequency: _frequency,
        );
  }

  Future<void> _socialSignIn(Future<void> Function() signIn) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await signIn();
      await _saveOnboardingAnswers();
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _friendlyError(Object e) {
    final message = e.toString();
    return message.length > 140 ? '${message.substring(0, 140)}...' : message;
  }

  void _next() {
    if (_step == _totalSteps - 1) {
      _submit();
      return;
    }
    _goToStep(_step + 1);
  }

  bool get _canContinue => switch (_step) {
        1 => _nameController.text.trim().isNotEmpty,
        5 => !_submitting && _emailController.text.contains('@') && _passwordController.text.length >= 8,
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
                  _AuthStep(
                    emailController: _emailController,
                    passwordController: _passwordController,
                    onChanged: () => setState(() {}),
                    submitting: _submitting,
                    error: _error,
                    onGoogleTap: () => _socialSignIn(ref.read(authServiceProvider).signInWithGoogle),
                    onAppleTap: () => _socialSignIn(ref.read(authServiceProvider).signInWithApple),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
              child: PrimaryButton(
                label: _step == _totalSteps - 1
                    ? (_submitting ? 'Creating account...' : 'Create account')
                    : 'Continue',
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
  const _AuthStep({
    required this.emailController,
    required this.passwordController,
    required this.onChanged,
    required this.submitting,
    required this.error,
    required this.onGoogleTap,
    required this.onAppleTap,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onChanged;
  final bool submitting;
  final String? error;
  final VoidCallback onGoogleTap;
  final VoidCallback onAppleTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fieldDecoration = InputDecoration(
      filled: true,
      fillColor: theme.cardTheme.color,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusRow),
        borderSide: BorderSide(color: theme.dividerTheme.color ?? AppColors.borderLight),
      ),
    );

    return _StepScaffold(
      title: 'Create your account',
      subtitle: 'Save your Mom and pick up where you left off.',
      child: ListView(
        children: [
          TextField(
            controller: emailController,
            onChanged: (_) => onChanged(),
            keyboardType: TextInputType.emailAddress,
            enabled: !submitting,
            decoration: fieldDecoration.copyWith(hintText: 'Email'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: passwordController,
            onChanged: (_) => onChanged(),
            obscureText: true,
            enabled: !submitting,
            decoration: fieldDecoration.copyWith(hintText: 'Password (min. 8 characters)'),
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(error!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.moodDisappointed)),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: Divider(color: theme.dividerTheme.color)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text('or', style: theme.textTheme.labelSmall),
              ),
              Expanded(child: Divider(color: theme.dividerTheme.color)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _AuthButton(
            icon: LucideIcons.globe,
            label: 'Continue with Google',
            onTap: submitting ? null : onGoogleTap,
          ),
          const SizedBox(height: AppSpacing.sm),
          _AuthButton(
            icon: LucideIcons.apple,
            label: 'Continue with Apple',
            onTap: submitting ? null : onAppleTap,
          ),
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
  const _AuthButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
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
