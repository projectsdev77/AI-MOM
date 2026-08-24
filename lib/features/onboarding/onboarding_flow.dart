import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/config/preview_mode.dart';
import '../../core/constants/check_in_frequency.dart';
import '../../core/providers/app_state_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/friendly_error.dart';
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
const _dailyRoutineOptions = ['Early riser', 'Standard 9-to-5 kind of day', 'Night owl', 'Pretty irregular'];
const _livingSituationOptions = ['On my own', 'With a partner or spouse', 'With family', 'With roommates'];
const _motivationStyleOptions = ['Gentle encouragement', 'Tough love, tell it straight', 'A mix of both'];
/// At least 8 characters with a mix of letters and numbers — strong
/// enough to matter without demanding symbols nobody remembers.
bool isStrongPassword(String password) {
  return password.length >= 8 &&
      RegExp(r'[A-Za-z]').hasMatch(password) &&
      RegExp(r'[0-9]').hasMatch(password);
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  final _pageController = PageController();
  int _step = 0;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _goals = <String>{};
  final _procrastination = <String>{};
  final _stressorController = TextEditingController();
  String? _dailyRoutine;
  String? _livingSituation;
  String? _motivationStyle;
  String _frequency = checkInFrequencyOptions.first;
  bool _submitting = false;
  bool _isLoginMode = false;
  String? _error;

  static const _totalSteps = 10;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _stressorController.dispose();
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

  void _previous() {
    if (_step > 0) _goToStep(_step - 1);
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final auth = ref.read(authServiceProvider);
      if (_isLoginMode) {
        await auth.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        // A returning user's profile already has real answers saved —
        // don't overwrite them with whatever's sitting in this blank
        // onboarding pass.
      } else {
        await auth.signUpWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
        );
        await _saveOnboardingAnswers();
      }
      // The router's auth-state listener takes it from here and redirects
      // to /dashboard once the session is set.
    } catch (e) {
      setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter your email above first, then tap "Forgot password?" again.');
      return;
    }
    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('If that email has an account, a reset link is on its way.')),
        );
      }
    } catch (e) {
      setState(() => _error = friendlyAuthError(e));
    }
  }

  void _startLogin() {
    setState(() => _isLoginMode = true);
    _goToStep(_totalSteps - 1);
  }

  void _backToSignUp() {
    setState(() {
      _isLoginMode = false;
      _error = null;
    });
    _goToStep(0);
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
          dailyRoutine: _dailyRoutine,
          livingSituation: _livingSituation,
          motivationStyle: _motivationStyle,
          currentStressor: _stressorController.text,
        );
  }

  Future<void> _socialSignIn(Future<void> Function() signIn) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await signIn();
      // Google/Apple sign-in doesn't distinguish new vs. returning users
      // up front the way email does, but overwriting a returning user's
      // real profile with blank onboarding answers is worse than a new
      // user occasionally needing to re-set them — Supabase's own
      // signInWithIdToken creates the account on first use either way.
      if (!_isLoginMode) await _saveOnboardingAnswers();
    } catch (e) {
      setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
        9 => !_submitting &&
            _emailController.text.contains('@') &&
            (_isLoginMode
                ? _passwordController.text.isNotEmpty
                : isStrongPassword(_passwordController.text)),
        _ => true,
      };

  /// Single-choice steps (avatar, daily routine, living situation,
  /// motivation style, check-in frequency) advance the moment someone
  /// taps an option — no Continue button, so there's nothing to tap
  /// through without actually answering. Multi-select and text steps
  /// keep the button since there's no single "done picking" tap.
  static const _autoAdvanceSteps = {0, 4, 5, 6, 8};
  bool get _isAutoAdvanceStep => _autoAdvanceSteps.contains(_step) && !_isLoginMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (_isLoginMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.lg, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.arrowLeft),
                      onPressed: _backToSignUp,
                      tooltip: 'Back',
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.md, AppSpacing.lg, 0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: _step > 0
                          ? IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(LucideIcons.arrowLeft),
                              onPressed: _previous,
                              tooltip: 'Back',
                            )
                          : null,
                    ),
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
            if (!_isLoginMode)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: TextButton(
                    onPressed: _startLogin,
                    child: const Text('Already have an account? Log in'),
                  ),
                ),
              ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _AvatarStep(onSelected: _next),
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
                  _SingleSelectStep(
                    title: "What's your daily routine like?",
                    options: _dailyRoutineOptions,
                    selected: _dailyRoutine,
                    onSelect: (o) {
                      setState(() => _dailyRoutine = o);
                      _next();
                    },
                  ),
                  _SingleSelectStep(
                    title: "What's your living situation?",
                    options: _livingSituationOptions,
                    selected: _livingSituation,
                    onSelect: (o) {
                      setState(() => _livingSituation = o);
                      _next();
                    },
                  ),
                  _SingleSelectStep(
                    title: 'What motivates you best?',
                    subtitle: "This shapes how Mom talks to you.",
                    options: _motivationStyleOptions,
                    selected: _motivationStyle,
                    onSelect: (o) {
                      setState(() => _motivationStyle = o);
                      _next();
                    },
                  ),
                  _StressorStep(controller: _stressorController, onChanged: () => setState(() {})),
                  _SingleSelectStep(
                    title: 'How often should Mom check in?',
                    subtitle: 'You can change this later in Settings.',
                    options: checkInFrequencyOptions,
                    selected: _frequency,
                    onSelect: (f) {
                      setState(() => _frequency = f);
                      _next();
                    },
                  ),
                  _AuthStep(
                    emailController: _emailController,
                    passwordController: _passwordController,
                    onChanged: () => setState(() {}),
                    submitting: _submitting,
                    error: _error,
                    isLoginMode: _isLoginMode,
                    onForgotPasswordTap: _forgotPassword,
                    onGoogleTap: () => _socialSignIn(ref.read(authServiceProvider).signInWithGoogle),
                    onAppleTap: () => _socialSignIn(ref.read(authServiceProvider).signInWithApple),
                    onPreviewTap: () {
                      previewModeEnabled = true;
                      context.go('/dashboard');
                    },
                  ),
                ],
              ),
            ),
            if (!_isAutoAdvanceStep)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                child: PrimaryButton(
                  label: _step == _totalSteps - 1
                      ? (_isLoginMode
                          ? (_submitting ? 'Logging in...' : 'Log in')
                          : (_submitting ? 'Creating account...' : 'Create account'))
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
  const _AvatarStep({required this.onSelected});
  final VoidCallback onSelected;

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
              onTap: () {
                ref.read(momAvatarStyleProvider.notifier).state = style;
                onSelected();
              },
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
      child: SingleChildScrollView(
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final o in options)
              _ChoiceCard(label: o, selected: selected.contains(o), onTap: () => onToggle(o)),
          ],
        ),
      ),
    );
  }
}

/// A single-choice question step — every "pick one of these" onboarding
/// screen (check-in frequency, daily routine, living situation,
/// motivation style) is this same shape. [selected] being `null` (no
/// pick made yet) just shows nothing highlighted — every one of these
/// questions is optional, so Continue never blocks on it.
class _SingleSelectStep extends StatelessWidget {
  const _SingleSelectStep({
    required this.title,
    this.subtitle,
    required this.options,
    required this.selected,
    required this.onSelect,
  });
  final String title;
  final String? subtitle;
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: title,
      subtitle: subtitle,
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (final o in options)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _ChoiceCard(
                  label: o,
                  selected: selected == o,
                  onTap: () => onSelect(o),
                  fullWidth: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Free-text, entirely optional — the only step with no chips to tap.
class _StressorStep extends StatelessWidget {
  const _StressorStep({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StepScaffold(
      title: "What's weighing on you most right now?",
      subtitle: 'Totally optional — skip if you\'d rather not say.',
      child: TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'e.g. work deadlines, money, a big life change...',
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
    required this.isLoginMode,
    required this.onForgotPasswordTap,
    required this.onGoogleTap,
    required this.onAppleTap,
    required this.onPreviewTap,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onChanged;
  final bool submitting;
  final String? error;
  final bool isLoginMode;
  final VoidCallback onForgotPasswordTap;
  final VoidCallback onGoogleTap;
  final VoidCallback onAppleTap;
  final VoidCallback onPreviewTap;

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
      title: isLoginMode ? 'Welcome back' : 'Create your account',
      subtitle: isLoginMode ? 'Log in to pick up where you left off.' : 'Save your Mom and pick up where you left off.',
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
            decoration: fieldDecoration.copyWith(
              hintText: isLoginMode ? 'Password' : 'Password (min. 8 characters)',
            ),
          ),
          if (isLoginMode) ...[
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: submitting ? null : onForgotPasswordTap,
                child: const Text('Forgot password?'),
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            _PasswordRequirements(password: passwordController.text),
          ],
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
          if (!isLoginMode) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'By continuing you agree to the Terms of Service and Privacy Policy.',
              style: theme.textTheme.labelSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: TextButton(
                onPressed: submitting ? null : onPreviewTap,
                child: const Text('Just want to look around? Preview without an account'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PasswordRequirements extends StatelessWidget {
  const _PasswordRequirements({required this.password});
  final String password;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checks = <(String, bool)>[
      ('At least 8 characters', password.length >= 8),
      ('A letter and a number', RegExp(r'[A-Za-z]').hasMatch(password) && RegExp(r'[0-9]').hasMatch(password)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, met) in checks)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                  met ? LucideIcons.circleCheck : LucideIcons.circle,
                  size: 14,
                  color: met ? AppColors.moodHappy : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: met ? AppColors.moodHappy : theme.textTheme.labelSmall?.color,
                  ),
                ),
              ],
            ),
          ),
      ],
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
