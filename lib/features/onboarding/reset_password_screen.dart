import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/providers/service_providers.dart';
import '../../core/routing/password_recovery_flag.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/mom_tokens.dart';
import '../../core/theme/mom_typography.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/utils/password.dart';
import '../../core/widgets/primary_button.dart';

/// Landed on from a tapped password-reset email link (see
/// AuthService.sendPasswordReset and main.dart's deep-link listener) —
/// the recovery session it establishes proves the account is theirs, so
/// this only asks for a new password, not the old one.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authServiceProvider).finishPasswordRecovery(_passwordController.text);
      isPasswordRecoverySession = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated.')),
        );
        context.go('/dashboard');
      }
    } catch (e) {
      setState(() => _error = friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancel() async {
    isPasswordRecoverySession = false;
    await ref.read(authServiceProvider).signOut();
    if (mounted) context.go('/onboarding');
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

    return Scaffold(
      backgroundColor: mom.shell,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.momGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Set a new password', style: MomText.screenTitle(mom.ink)),
              const SizedBox(height: 6),
              Text("You're in — pick a new password to finish.", style: MomText.body(mom.inkSoft)),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _passwordController,
                autofocus: true,
                obscureText: _obscure,
                enabled: !_submitting,
                onChanged: (_) => setState(() {}),
                style: MomText.body(mom.ink),
                decoration: fieldDecoration.copyWith(
                  hintText: 'New password (min. 8 characters)',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? LucideIcons.eye : LucideIcons.eyeOff, size: 20, color: mom.inkMuted),
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _PasswordRequirements(password: _passwordController.text),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!, style: MomText.meta(mom.danger)),
              ],
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: _submitting ? 'Saving…' : 'Save new password',
                onPressed: (isStrongPassword(_passwordController.text) && !_submitting) ? _submit : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: GestureDetector(
                  onTap: _submitting ? null : _cancel,
                  child: Text('Cancel', style: MomText.control(mom.inkMuted)),
                ),
              ),
            ],
          ),
        ),
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
