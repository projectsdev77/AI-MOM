import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/finance_repository.dart';
import '../repositories/health_repository.dart';
import 'service_providers.dart';

String? _currentUserId(Ref ref) => ref.watch(supabaseClientProvider).auth.currentUser?.id;

final expensesThisMonthProvider = FutureProvider.autoDispose<List<ExpenseRow>>((ref) async {
  final userId = _currentUserId(ref);
  if (userId == null) return const [];
  return ref.watch(financeRepositoryProvider).fetchExpensesThisMonth(userId);
});

final overallBudgetCentsProvider = FutureProvider.autoDispose<int?>((ref) async {
  final userId = _currentUserId(ref);
  if (userId == null) return null;
  return ref.watch(financeRepositoryProvider).fetchOverallBudgetCents(userId);
});

/// Null means "no goals set yet" — the Health card prompts for them the
/// first time this loads, per the planning decision (asked on first
/// visit to the tab, not at onboarding).
final healthGoalsProvider = FutureProvider.autoDispose<HealthGoals?>((ref) async {
  final userId = _currentUserId(ref);
  if (userId == null) return null;
  return ref.watch(healthRepositoryProvider).fetchGoals(userId);
});

final healthTodayProvider = FutureProvider.autoDispose<HealthToday>((ref) async {
  final userId = _currentUserId(ref);
  if (userId == null) return const HealthToday(waterCount: 0, workoutMinutes: 0);
  return ref.watch(healthRepositoryProvider).fetchToday(userId);
});
