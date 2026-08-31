import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/config/preview_mode.dart';
import '../../core/constants/check_in_frequency.dart';
import '../../core/providers/app_state_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/mom_mood.dart';
import '../../core/theme/mom_tokens.dart';
import '../../core/theme/mom_typography.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/utils/password.dart';
import '../../core/widgets/mom_avatar.dart';
import '../../core/widgets/mom_components.dart';
import '../../core/widgets/primary_button.dart';
import '../settings/legal_screens.dart';

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
const _dailyRoutineSubs = ['Up before 7, done by dinner', 'Weekday rhythm, protected evenings', 'Peak focus after 21:00', 'Shifts, travel, no fixed week'];
const _livingSituationOptions = ['On my own', 'With a partner or spouse', 'With family', 'With roommates'];
const _livingSituationSubs = ['Nobody else picks up the slack', 'Shared chores, shared blame', 'Kids, parents, or both', 'The dishes are political'];
const _motivationStyleOptions = ['Gentle encouragement', 'Tough love, tell it straight', 'A mix of both'];
const _motivationStyleSubs = ['Warm, patient, never sharp', 'She will bring up the streak you dropped', "Kind until you've stalled twice"];
const _frequencySubs = ['One morning nudge', 'Morning plan, evening review', 'For the deadline weeks', 'You asked for this'];

const _avatarTraits = [
  'Sweet — but she keeps a list.',
  'No excuses today, love.',
  'Have you eaten yet?',
  'Raises exactly one eyebrow.',
  'Celebrates every small win.',
];

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
  bool _hasPickedAvatar = false;
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
      duration: const Duration(milliseconds: 240),
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
    setState(() => _error = null);
    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('If that email has an account, a reset link is on its way — tap it to set a new password.')),
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
        0 => _hasPickedAvatar,
        1 => _nameController.text.trim().isNotEmpty,
        9 => !_submitting &&
            _emailController.text.contains('@') &&
            (_isLoginMode
                ? _passwordController.text.isNotEmpty
                : isStrongPassword(_passwordController.text)),
        _ => true,
      };

  /// Single-choice steps (daily routine, living situation, motivation
  /// style, check-in frequency) advance the moment someone taps an
  /// option — no Continue button, so there's nothing to tap through
  /// without actually answering. The avatar step keeps a Continue
  /// button (disabled until a style is picked) since it's the very
  /// first step and an instant jump away could feel like a misfire.
  /// Multi-select and text steps keep the button too, since there's no
  /// single "done picking" tap.
  static const _autoAdvanceSteps = {4, 5, 6, 8};
  bool get _isAutoAdvanceStep => _autoAdvanceSteps.contains(_step) && !_isLoginMode;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return Scaffold(
      backgroundColor: mom.shell,
      body: SafeArea(
        top: _step != 0,
        child: Column(
          children: [
            if (_isLoginMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.lg, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(LucideIcons.chevronLeft, size: 22, color: mom.espresso),
                      onPressed: _backToSignUp,
                      tooltip: 'Back',
                    ),
                  ],
                ),
              )
            else if (_step > 0)
              _ProgressHeader(step: _step, totalSteps: _totalSteps, onBack: _previous, onLogin: _startLogin),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _AvatarStep(
                    hasPicked: _hasPickedAvatar,
                    onSelected: () => setState(() => _hasPickedAvatar = true),
                    onLogin: _startLogin,
                  ),
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
                    momBubble: "Noted. I'm writing all of this down, by the way.",
                    momExpression: MomExpression.notes,
                  ),
                  _SingleSelectStep(
                    title: "What's your daily routine like?",
                    options: _dailyRoutineOptions,
                    subs: _dailyRoutineSubs,
                    selected: _dailyRoutine,
                    onSelect: (o) {
                      setState(() => _dailyRoutine = o);
                      _next();
                    },
                  ),
                  _SingleSelectStep(
                    title: "What's your living situation?",
                    options: _livingSituationOptions,
                    subs: _livingSituationSubs,
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
                    subs: _motivationStyleSubs,
                    selected: _motivationStyle,
                    onSelect: (o) {
                      setState(() => _motivationStyle = o);
                      _next();
                    },
                    momBubble: "Tough love it is. Don't say I didn't warn you.",
                    momExpression: MomExpression.mad,
                  ),
                  _StressorStep(controller: _stressorController, onChanged: () => setState(() {})),
                  _FrequencyStep(
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
                padding: const EdgeInsets.fromLTRB(AppSpacing.momGutter, 0, AppSpacing.momGutter, AppSpacing.lg),
                child: PrimaryButton(
                  label: _step == _totalSteps - 1
                      ? (_isLoginMode
                          ? (_submitting ? 'Logging in…' : 'Log in')
                          : (_submitting ? 'Creating account…' : 'Create account'))
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

/// Shared onboarding chrome for every step but the first (which places
/// its own progress row on the peach hero instead).
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step, required this.totalSteps, required this.onBack, required this.onLogin});
  final int step;
  final int totalSteps;
  final VoidCallback onBack;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.md, AppSpacing.momGutter, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              SizedBox(
                width: 40,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(LucideIcons.chevronLeft, size: 22, color: mom.espresso),
                  onPressed: onBack,
                  tooltip: 'Back',
                ),
              ),
              for (var i = 0; i < totalSteps; i++)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i == totalSteps - 1 ? 0 : 5),
                    decoration: BoxDecoration(
                      color: i <= step ? mom.doneOrange : mom.fieldBorder,
                      borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: GestureDetector(
              onTap: onLogin,
              child: RichText(
                text: TextSpan(
                  style: MomText.meta(mom.inkMuted, size: 12),
                  children: [
                    const TextSpan(text: 'Already have an account? '),
                    TextSpan(text: 'Log in', style: MomText.control(mom.espresso, size: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
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
    final mom = context.mom;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.momGutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: MomText.screenTitle(mom.ink)),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle!, style: MomText.body(mom.inkMuted)),
          ],
          const SizedBox(height: AppSpacing.xl),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _AvatarStep extends ConsumerWidget {
  const _AvatarStep({required this.hasPicked, required this.onSelected, required this.onLogin});
  final bool hasPicked;
  final VoidCallback onSelected;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mom = context.mom;
    final selected = ref.watch(momAvatarStyleProvider);
    final styles = MomAvatarStyle.values;
    final traitIndex = styles.indexOf(selected);

    // The header and the sheet below it are siblings painted in order, so
    // without this Stack the sheet (painted second) would simply paint
    // over the bottom half of the avatar peeking out of the header
    // below it — wrapping both in a Stack, with the header painted last,
    // keeps the avatar visible on top the way the peach panel's -84
    // overflow and the sheet's matching 92 top padding actually intend.
    return SingleChildScrollView(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            children: [
              const SizedBox(height: 300),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 92, 20, 24),
                decoration: BoxDecoration(
                  color: mom.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.momRadiusSheet)),
                ),
                child: Column(
                  children: [
                    Text('Meet your Mom', style: MomText.screenTitle(mom.ink), textAlign: TextAlign.center),
                    const SizedBox(height: 6),
                    Text("Pick a look. She's Mom either way.", style: MomText.body(mom.inkMuted), textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final style in styles)
                          GestureDetector(
                            onTap: () {
                              ref.read(momAvatarStyleProvider.notifier).state = style;
                              onSelected();
                            },
                            child: Opacity(
                              opacity: hasPicked && selected == style ? 1 : 0.72,
                              child: Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: hasPicked && selected == style ? mom.espresso : Colors.transparent,
                                    width: 2.5,
                                  ),
                                  boxShadow: hasPicked && selected == style
                                      ? [BoxShadow(color: mom.promoPeach, blurRadius: 0, spreadRadius: 4)]
                                      : null,
                                ),
                                child: MomAvatar(
                                  style: style,
                                  expression: hasPicked && selected == style ? MomExpression.happy : MomExpression.normal,
                                  showMoodBadge: false,
                                  size: 60,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      decoration: BoxDecoration(color: mom.shell, borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mom', style: MomText.cardTitle(mom.ink)),
                          const SizedBox(height: 2),
                          Text(traitIndex >= 0 ? _avatarTraits[traitIndex] : _avatarTraits[0], style: MomText.body(mom.inkSoft)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            width: double.infinity,
            height: 300,
            padding: const EdgeInsets.fromLTRB(AppSpacing.sm, 0, AppSpacing.momGutter, 0),
            decoration: BoxDecoration(color: mom.promoPeach),
            child: SafeArea(
              bottom: false,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 40),
                          for (var i = 0; i < 10; i++)
                            Expanded(
                              child: Container(
                                height: 4,
                                margin: EdgeInsets.only(right: i == 9 ? 0 : 5),
                                decoration: BoxDecoration(
                                  color: i == 0 ? mom.doneOrange : mom.peachOnPeach,
                                  borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill),
                                ),
                              ),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: onLogin,
                            child: RichText(
                              text: TextSpan(
                                style: MomText.meta(mom.peachPanelMuted, size: 12),
                                children: [
                                  const TextSpan(text: 'Already have an account? '),
                                  TextSpan(text: 'Log in', style: MomText.control(mom.espresso, size: 12)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: -84,
                    left: 0,
                    right: 0,
                    child: Center(child: MomAvatar(style: selected, expression: MomExpression.notes, showMoodBadge: false, size: 168)),
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

class _NameStep extends ConsumerWidget {
  const _NameStep({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mom = context.mom;
    return _StepScaffold(
      title: 'What should Mom call you?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard), boxShadow: MomElevation.card),
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: MomText.rowLabel(mom.ink, selected: true),
              cursorColor: mom.doneOrange,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Your name',
                hintStyle: MomText.placeholder(mom.placeholderText, size: 15),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          MomMessageCard(
            avatarStyle: ref.watch(momAvatarStyleProvider),
            expression: MomExpression.happy,
            eyebrow: 'Mom says',
            message: "Lovely name. Now let's see what you keep putting off, sweetheart.",
          ),
        ],
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
    this.momBubble,
    this.momExpression,
  });

  final String title;
  final String? subtitle;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final String? momBubble;
  final MomExpression? momExpression;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: title,
      subtitle: subtitle,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final o in options) MomChip(label: o, selected: selected.contains(o), onTap: () => onToggle(o)),
              ],
            ),
            if (momBubble != null) ...[
              const SizedBox(height: AppSpacing.lg),
              Consumer(
                builder: (context, ref, _) => MomMessageCard(
                  avatarStyle: ref.watch(momAvatarStyleProvider),
                  expression: momExpression ?? MomExpression.normal,
                  eyebrow: 'Mom says',
                  message: momBubble!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A single-choice question step — every "pick one of these" onboarding
/// screen (daily routine, living situation, motivation style) is this
/// same shape. [selected] being `null` (no pick made yet) just shows
/// nothing highlighted — every one of these questions is optional, so
/// Continue never blocks on it.
class _SingleSelectStep extends StatelessWidget {
  const _SingleSelectStep({
    required this.title,
    this.subtitle,
    required this.options,
    this.subs,
    required this.selected,
    required this.onSelect,
    this.momBubble,
    this.momExpression,
  });
  final String title;
  final String? subtitle;
  final List<String> options;
  final List<String>? subs;
  final String? selected;
  final ValueChanged<String> onSelect;
  final String? momBubble;
  final MomExpression? momExpression;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: title,
      subtitle: subtitle,
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (var i = 0; i < options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.momRowGap),
                child: MomOptionRow(
                  label: options[i],
                  sub: subs != null ? subs![i] : null,
                  selected: selected == options[i],
                  onTap: () => onSelect(options[i]),
                ),
              ),
            if (momBubble != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Consumer(
                builder: (context, ref, _) => MomMessageCard(
                  avatarStyle: ref.watch(momAvatarStyleProvider),
                  expression: momExpression ?? MomExpression.normal,
                  eyebrow: 'Mom says',
                  message: momBubble!,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FrequencyStep extends ConsumerWidget {
  const _FrequencyStep({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mom = context.mom;
    final avatarStyle = ref.watch(momAvatarStyleProvider);
    final index = checkInFrequencyOptions.indexOf(selected).clamp(0, _frequencySubs.length - 1);

    return _StepScaffold(
      title: 'How often should Mom check in?',
      subtitle: 'You can change this later in Settings.',
      child: SingleChildScrollView(
        child: Column(
          children: [
            for (var i = 0; i < checkInFrequencyOptions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.momRowGap),
                child: MomOptionRow(
                  label: checkInFrequencyOptions[i],
                  sub: _frequencySubs[i],
                  selected: selected == checkInFrequencyOptions[i],
                  onTap: () => onSelect(checkInFrequencyOptions[i]),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
              decoration: BoxDecoration(color: mom.promoPeach, borderRadius: BorderRadius.circular(AppSpacing.momRadiusPanel)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MomAvatar(style: avatarStyle, expression: MomExpression.happy, showMoodBadge: false, size: 52),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_frequencySubs[index], style: MomText.momMessage(mom.ink))),
                ],
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
    final mom = context.mom;
    return _StepScaffold(
      title: "What's weighing on you most right now?",
      subtitle: "Totally optional — skip if you'd rather not say.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            constraints: const BoxConstraints(minHeight: 132),
            decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: controller,
                  onChanged: (_) => onChanged(),
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
                Text('${controller.text.length} / 200', style: MomText.meta(mom.placeholderText, size: 11)),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Consumer(
            builder: (context, ref, _) => MomMessageCard(
              avatarStyle: ref.watch(momAvatarStyleProvider),
              expression: MomExpression.normal,
              eyebrow: 'Mom says',
              message: 'Between us. I only bring it up when it helps.',
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthStep extends StatefulWidget {
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
  State<_AuthStep> createState() => _AuthStepState();
}

class _AuthStepState extends State<_AuthStep> {
  bool _obscurePassword = true;
  late final _termsRecognizer = TapGestureRecognizer()
    ..onTap = () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()));
  late final _privacyRecognizer = TapGestureRecognizer()
    ..onTap = () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final fieldDecoration = InputDecoration(
      filled: true,
      fillColor: mom.surface,
      hintStyle: MomText.placeholder(mom.placeholderText),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.momGutter, vertical: AppSpacing.md),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard),
        borderSide: BorderSide(color: mom.espresso, width: 1.5),
      ),
    );

    return _StepScaffold(
      title: widget.isLoginMode ? 'Welcome back' : 'Create your account',
      subtitle: widget.isLoginMode
          ? 'Log in to pick up where you left off.'
          : 'Save your Mom and pick up where you left off.',
      child: ListView(
        children: [
          if (!widget.isLoginMode) ...[
            Consumer(
              builder: (context, ref, _) => Row(
                children: [
                  MomAvatar(style: ref.watch(momAvatarStyleProvider), expression: MomExpression.happy, showMoodBadge: false, size: 40),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Almost there.', style: MomText.body(mom.inkSoft))),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          TextField(
            controller: widget.emailController,
            onChanged: (_) => widget.onChanged(),
            keyboardType: TextInputType.emailAddress,
            enabled: !widget.submitting,
            style: MomText.body(mom.ink),
            decoration: fieldDecoration.copyWith(hintText: 'Email'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: widget.passwordController,
            onChanged: (_) => widget.onChanged(),
            obscureText: _obscurePassword,
            enabled: !widget.submitting,
            style: MomText.body(mom.ink),
            decoration: fieldDecoration.copyWith(
              hintText: widget.isLoginMode ? 'Password' : 'Password (min. 8 characters)',
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? LucideIcons.eye : LucideIcons.eyeOff, size: 20, color: mom.inkMuted),
                tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          if (widget.isLoginMode) ...[
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: widget.submitting ? null : widget.onForgotPasswordTap,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Forgot password?', style: MomText.control(mom.espresso)),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.sm),
            _PasswordRequirements(password: widget.passwordController.text),
          ],
          if (widget.error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(widget.error!, style: MomText.meta(mom.danger)),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: Divider(color: mom.fieldBorder)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text('or', style: MomText.meta(mom.inkMuted)),
              ),
              Expanded(child: Divider(color: mom.fieldBorder)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          MomSecondaryButton(
            icon: LucideIcons.globe,
            label: 'Continue with Google',
            onPressed: widget.submitting ? null : widget.onGoogleTap,
          ),
          const SizedBox(height: AppSpacing.sm),
          MomSecondaryButton(
            icon: LucideIcons.apple,
            label: 'Continue with Apple',
            onPressed: widget.submitting ? null : widget.onAppleTap,
          ),
          if (!widget.isLoginMode) ...[
            const SizedBox(height: AppSpacing.lg),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: MomText.meta(mom.inkMuted),
                children: [
                  const TextSpan(text: 'By continuing you agree to the '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: MomText.control(mom.espresso, size: 11.5),
                    recognizer: _termsRecognizer,
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: MomText.control(mom.espresso, size: 11.5),
                    recognizer: _privacyRecognizer,
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: GestureDetector(
                onTap: widget.submitting ? null : widget.onPreviewTap,
                child: Text('Just looking around? Preview without an account', style: MomText.control(mom.inkMuted)),
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
    final mom = context.mom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final requirement in PasswordRequirement.values)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: requirement.isMet(password) ? mom.espresso : Colors.transparent,
                    border: Border.all(color: requirement.isMet(password) ? mom.espresso : mom.checkIdleBorder, width: 1.5),
                  ),
                  child: requirement.isMet(password) ? const Icon(LucideIcons.check, size: 10, color: Colors.white) : null,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(requirement.label, style: MomText.meta(mom.inkMuted)),
              ],
            ),
          ),
      ],
    );
  }
}
