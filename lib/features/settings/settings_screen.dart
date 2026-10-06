import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/check_in_frequency.dart';
import '../../core/models/plan.dart';
import '../../core/models/subscription_status.dart';
import '../../core/providers/app_state_provider.dart';
import '../../core/providers/service_providers.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/purchases_service.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/mom_mood.dart';
import '../../core/theme/mom_tokens.dart';
import '../../core/theme/mom_typography.dart';
import '../../core/utils/friendly_error.dart';
import '../../core/utils/password.dart';
import '../../core/widgets/mom_avatar.dart';
import '../../core/widgets/mom_components.dart';
import 'legal_screens.dart';
import 'onboarding_answers_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmAndRun({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() action,
  }) async {
    final mom = context.mom;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel, style: TextStyle(color: mom.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    }
  }

  Future<void> _pickCheckInFrequency(BuildContext context, WidgetRef ref, String current) async {
    final mom = context.mom;
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Check-in frequency'),
        children: [
          for (final option in checkInFrequencyOptions)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, option),
              child: Row(
                children: [
                  Icon(
                    option == current ? LucideIcons.circleCheck : LucideIcons.circle,
                    size: 18,
                    color: option == current ? mom.espresso : null,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(option),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null || selected == current) return;
    try {
      await ref.read(profileRepositoryProvider).updateCheckInFrequency(userId: userId, frequency: selected);
      ref.invalidate(profileProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    }
  }

  Future<void> _pickAppearance(BuildContext context, WidgetRef ref, ThemeMode current) async {
    final mom = context.mom;
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Appearance'),
        children: [
          for (final mode in ThemeMode.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, mode),
              child: Row(
                children: [
                  Icon(
                    mode == current ? LucideIcons.circleCheck : LucideIcons.circle,
                    size: 18,
                    color: mode == current ? mom.espresso : null,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(themeModeLabel(mode)),
                ],
              ),
            ),
        ],
      ),
    );
    if (selected == null || selected == current) return;
    ref.read(themeModeProvider.notifier).state = selected;
    await saveThemeMode(selected);
  }

  void _changeAvatar(BuildContext context, WidgetRef ref, MomAvatarStyle current) {
    showMomAvatarPicker(
      context,
      current: current,
      onSelected: (style) async {
        ref.read(momAvatarStyleProvider.notifier).state = style;
        final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
        if (userId == null) return;
        try {
          await ref.read(profileRepositoryProvider).updateMomAvatarStyle(userId: userId, style: style.name);
          ref.invalidate(profileProvider);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
          }
        }
      },
    );
  }

  Future<void> _changeName(BuildContext context, WidgetRef ref, String currentName) async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    final controller = TextEditingController(text: currentName);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Your name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              try {
                await ref.read(profileRepositoryProvider).updateName(userId: userId, name: name);
                ref.invalidate(profileProvider);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeEmail(BuildContext context, WidgetRef ref, String currentEmail) async {
    final controller = TextEditingController(text: currentEmail);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change email'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'New email'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final email = controller.text.trim();
              if (!email.contains('@')) return;
              try {
                await ref.read(authServiceProvider).updateEmail(email);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Check $email to confirm the change.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    var obscureOld = true;
    var obscureNew = true;
    String? error;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: oldController,
                  autofocus: true,
                  obscureText: obscureOld,
                  onChanged: (_) => setState(() => error = null),
                  decoration: InputDecoration(
                    hintText: 'Current password',
                    suffixIcon: IconButton(
                      icon: Icon(obscureOld ? LucideIcons.eye : LucideIcons.eyeOff, size: 20),
                      tooltip: obscureOld ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => obscureOld = !obscureOld),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: newController,
                  obscureText: obscureNew,
                  onChanged: (_) => setState(() => error = null),
                  decoration: InputDecoration(
                    hintText: 'New password',
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? LucideIcons.eye : LucideIcons.eyeOff, size: 20),
                      tooltip: obscureNew ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final requirement in PasswordRequirement.values)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(
                          requirement.isMet(newController.text) ? LucideIcons.circleCheck : LucideIcons.circle,
                          size: 14,
                          color: requirement.isMet(newController.text)
                              ? context.mom.doneOrange
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          requirement.label,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: requirement.isMet(newController.text) ? context.mom.doneOrange : null,
                              ),
                        ),
                      ],
                    ),
                  ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(error!, style: TextStyle(color: context.mom.danger, fontSize: 12.5)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: (oldController.text.isNotEmpty && isStrongPassword(newController.text))
                  ? () async {
                      try {
                        await ref.read(authServiceProvider).changePassword(
                              currentPassword: oldController.text,
                              newPassword: newController.text,
                            );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password updated.')),
                          );
                        }
                      } on WrongCurrentPasswordException {
                        setState(() => error = 'Your current password is wrong.');
                      } catch (e) {
                        setState(() => error = friendlyAuthError(e));
                      }
                    }
                  : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openNotificationSettings(BuildContext context) async {
    if (kIsWeb || !(await openAppSettings())) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Open your phone's Settings app to manage AI Mom's notifications.")),
        );
      }
    }
  }

  Future<void> _setPushNudgesEnabled(BuildContext context, WidgetRef ref, bool enabled) async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    try {
      await ref.read(profileRepositoryProvider).updatePushNudgesEnabled(userId: userId, enabled: enabled);
      ref.invalidate(profileProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mom = context.mom;
    final plan = ref.watch(planProvider);
    final user = ref.watch(supabaseClientProvider).auth.currentUser;
    final authService = ref.read(authServiceProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final checkInFrequency = (profile?['check_in_frequency'] as String?) ?? checkInFrequencyOptions.first;
    final themeMode = ref.watch(themeModeProvider);
    final avatarStyle = ref.watch(effectiveMomAvatarProvider);

    return Scaffold(
      backgroundColor: mom.shell,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.momGutter, AppSpacing.lg, AppSpacing.momGutter, AppSpacing.xxl),
          children: [
            Text('Settings', style: MomText.screenTitle(mom.ink)),
            const SizedBox(height: AppSpacing.momSectionGap),
            _IdentityPanel(
              avatarStyle: avatarStyle,
              planName: plan.displayName,
              checkInFrequency: checkInFrequency,
              onChangeAvatar: () => _changeAvatar(context, ref, avatarStyle),
            ),
            const SizedBox(height: AppSpacing.momSectionGap),
            _Group(title: 'Account', rows: [
              _Row(
                icon: LucideIcons.user,
                label: 'Name',
                value: (profile?['name'] as String?) ?? '',
                onTap: () => _changeName(context, ref, (profile?['name'] as String?) ?? ''),
              ),
              _Row(
                icon: LucideIcons.mail,
                label: 'Change email',
                value: user?.email ?? '',
                onTap: () => _changeEmail(context, ref, user?.email ?? ''),
              ),
              _Row(
                icon: LucideIcons.lock,
                label: 'Change password',
                onTap: () => _changePassword(context, ref),
              ),
              _Row(
                icon: LucideIcons.userX,
                label: 'Delete account',
                destructive: true,
                onTap: () => _confirmAndRun(
                  context: context,
                  title: 'Delete your account?',
                  message: 'This permanently deletes your tasks, chat history, spending, and health data. This cannot be undone.',
                  confirmLabel: 'Delete',
                  action: authService.deleteAccount,
                ),
              ),
            ]),
            const SubscriptionGroup(),
            _Group(title: 'Mom', rows: [
              _Row(
                icon: LucideIcons.smile,
                label: "Change Mom's avatar",
                onTap: () => _changeAvatar(context, ref, avatarStyle),
              ),
              _Row(
                icon: LucideIcons.bellRing,
                label: 'Check-in frequency',
                value: checkInFrequency,
                onTap: () => _pickCheckInFrequency(context, ref, checkInFrequency),
              ),
              _Row(
                icon: LucideIcons.notebookPen,
                label: 'Your answers',
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OnboardingAnswersScreen())),
              ),
            ]),
            const SizedBox(height: AppSpacing.momRowGap),
            MomMessageCard(
              avatarStyle: avatarStyle,
              expression: MomExpression.notes,
              eyebrow: 'Between us',
              message: "This is your Mom, tuned to how you like her. Change any of it whenever you want.",
            ),
            const SizedBox(height: AppSpacing.momRowGap),
            _Group(title: 'Notifications', rows: [
              _Row(
                icon: LucideIcons.bell,
                label: 'System notification settings',
                onTap: () => _openNotificationSettings(context),
              ),
            ]),
            _ToggleRow(
              icon: LucideIcons.messageCircleHeart,
              label: "Nudge me about today's list",
              value: (profile?['push_nudges_enabled'] as bool?) ?? true,
              onChanged: (enabled) => _setPushNudgesEnabled(context, ref, enabled),
            ),
            _Group(title: 'Preferences', rows: [
              _Row(
                icon: LucideIcons.moonStar,
                label: 'Appearance',
                value: themeModeLabel(themeMode),
                onTap: () => _pickAppearance(context, ref, themeMode),
              ),
            ]),
            _Group(title: 'Support & legal', rows: [
              _Row(
                icon: LucideIcons.circleHelp,
                label: 'Help & contact support',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HelpScreen())),
              ),
              _Row(
                icon: LucideIcons.fileText,
                label: 'Terms of Service',
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsOfServiceScreen())),
              ),
              _Row(
                icon: LucideIcons.shieldCheck,
                label: 'Privacy Policy',
                onTap: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
              ),
              _Row(
                icon: LucideIcons.scrollText,
                label: 'Open-source licenses',
                onTap: () => showLicensePage(context: context, applicationName: 'AI Mom'),
              ),
            ]),
            _Group(title: 'Session', rows: [
              _Row(
                icon: LucideIcons.logOut,
                label: 'Log out',
                onTap: () => _confirmAndRun(
                  context: context,
                  title: 'Log out?',
                  message: "You'll need to sign back in to see your tasks and chats.",
                  confirmLabel: 'Log out',
                  action: authService.signOut,
                ),
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            const _VersionLine(),
          ],
        ),
      ),
    );
  }
}

class _IdentityPanel extends StatelessWidget {
  const _IdentityPanel({
    required this.avatarStyle,
    required this.planName,
    required this.checkInFrequency,
    required this.onChangeAvatar,
  });

  final MomAvatarStyle avatarStyle;
  final String planName;
  final String checkInFrequency;
  final VoidCallback onChangeAvatar;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(color: mom.promoPeach, borderRadius: BorderRadius.circular(AppSpacing.momRadiusPanel)),
      child: Row(
        children: [
          MomAvatar(style: avatarStyle, expression: MomExpression.happy, showMoodBadge: false, size: 52),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Mom, as you set her up', style: MomText.cardTitle(mom.ink)),
                Text('$planName · checks in ${checkInFrequency.toLowerCase()}', style: MomText.rowSub(mom.peachPanelMuted)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onChangeAvatar,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusPill)),
              child: Text('Change', style: MomText.control(mom.espresso)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows});
  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.momRowGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: 4),
            child: Text(title, style: MomText.meta(mom.inkMuted, size: 12)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard)),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  rows[i],
                  if (i != rows.length - 1) Divider(height: 1, color: mom.hairline),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.icon, required this.label, required this.value, required this.onChanged});
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.momRowGap),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(color: mom.surface, borderRadius: BorderRadius.circular(AppSpacing.momRadiusCard)),
        child: Row(
          children: [
            Icon(icon, size: 20, color: mom.espresso),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: MomText.rowLabel(mom.ink))),
            MomToggle(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    this.value,
    this.subtitle,
    this.busy = false,
    this.destructive = false,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String? value;

  /// A smaller line under the label.
  final String? subtitle;

  /// Shows a spinner in place of the arrow and ignores taps while working.
  final bool busy;
  final bool destructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    final labelColor = destructive ? mom.danger : mom.ink;
    final chevronColor = destructive ? mom.dangerChevron : mom.inkMuted;
    return InkWell(
      onTap: busy ? null : (onTap ?? () {}),
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSpacing.momMinHitTarget),
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 20, color: destructive ? mom.danger : mom.espresso),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: MomText.rowLabel(labelColor)),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: MomText.meta(mom.inkMuted, size: 12)),
                  ],
                ],
              ),
            ),
            if (value != null && value!.isNotEmpty)
              Text(value!, style: MomText.meta(mom.inkMuted, size: 12.5)),
            const SizedBox(width: AppSpacing.xs),
            if (busy)
              SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: mom.espresso))
            else
              Icon(LucideIcons.chevronRight, size: 17, color: chevronColor),
          ],
        ),
      ),
    );
  }
}

/// Settings > Subscription: the current plan and what it's doing, restoring a
/// purchase made earlier, and getting to the store to change or cancel.
class SubscriptionGroup extends ConsumerStatefulWidget {
  const SubscriptionGroup({super.key});

  @override
  ConsumerState<SubscriptionGroup> createState() => SubscriptionGroupState();
}

class SubscriptionGroupState extends ConsumerState<SubscriptionGroup> {
  bool _restoring = false;

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _restore() async {
    if (_restoring) return;
    if (!await PurchasesService.isAvailable) {
      _say("Purchases aren't available on this device.");
      return;
    }
    setState(() => _restoring = true);
    try {
      final wasAlreadyFull = ref.read(subscriptionStatusProvider).isActive;
      final restoredFull = await PurchasesService.restorePurchases();
      _say(restoreResultMessage(restoredFull: restoredFull, wasAlreadyFull: wasAlreadyFull));
    } catch (e) {
      _say(friendlyError(e));
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _manage() async {
    final status = ref.read(subscriptionStatusProvider);
    final plan = ref.read(planProvider);
    switch (decideManageAction(status, isFull: plan.isFull, isWeb: kIsWeb)) {
      case ManageAction.upgrade:
        context.push('/upgrade');
      case ManageAction.openStore:
        final url = storeSubscriptionsUrl(status, isIOS: Platform.isIOS);
        final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).catchError((_) => false);
        if (!opened) _say('Manage your subscription from your App Store or Play Store account.');
      case ManageAction.testPurchase:
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Test purchase'),
            content: const Text(
              'This plan was bought with the test store, so there is no App Store or Play Store subscription to manage. '
              'A real purchase opens your store account here.',
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      case ManageAction.notStoreBacked:
        _say("Your Full plan isn't tied to a store subscription, so there's nothing to manage here.");
      case ManageAction.unavailable:
        _say('Manage your subscription from your App Store or Play Store account.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(planProvider);
    final status = ref.watch(subscriptionStatusProvider);
    return _Group(title: 'Subscription', rows: [
      _Row(
        icon: LucideIcons.crown,
        label: 'Current plan',
        value: status.planTitle(isFull: plan.isFull),
        subtitle: status.summary,
        onTap: _manage,
      ),
      _Row(
        icon: LucideIcons.refreshCw,
        label: 'Restore purchases',
        busy: _restoring,
        onTap: _restore,
      ),
      _Row(
        icon: LucideIcons.externalLink,
        label: 'Manage subscription',
        onTap: _manage,
      ),
    ]);
  }
}

/// Reads the actual running build's version/build number rather than
/// duplicating pubspec.yaml's value as a string that could drift out of
/// sync with it.
class _VersionLine extends StatelessWidget {
  const _VersionLine();

  @override
  Widget build(BuildContext context) {
    final mom = context.mom;
    return Center(
      child: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          final label = info == null ? ' ' : 'Version ${info.version} (${info.buildNumber})';
          return Text(label, style: MomText.meta(mom.inkMuted));
        },
      ),
    );
  }
}
