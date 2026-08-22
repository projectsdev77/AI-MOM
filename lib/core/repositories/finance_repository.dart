import 'package:supabase_flutter/supabase_flutter.dart';

class ExpenseRow {
  const ExpenseRow({
    required this.id,
    required this.amountCents,
    required this.category,
    required this.spentAt,
    this.note,
  });

  final String id;
  final int amountCents;
  final String category;
  final DateTime spentAt;
  final String? note;
}

/// Manual entry only (no bank linking) — amounts are stored as integer
/// cents to avoid float rounding issues. The overall monthly budget is
/// the `budgets` row with `category = 'overall'`; per-category budgets
/// are supported by the schema but not surfaced in the UI yet.
class FinanceRepository {
  FinanceRepository(this._client);

  final SupabaseClient _client;

  static const overallBudgetCategory = 'overall';

  String _monthStart() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-01';
  }

  Future<List<ExpenseRow>> fetchExpensesThisMonth(String userId) async {
    final rows = await _client
        .from('expenses')
        .select()
        .eq('user_id', userId)
        .gte('spent_at', _monthStart())
        .order('spent_at', ascending: false);
    return [
      for (final row in rows)
        ExpenseRow(
          id: row['id'] as String,
          amountCents: row['amount_cents'] as int,
          category: row['category'] as String,
          spentAt: DateTime.parse(row['spent_at'] as String),
          note: row['note'] as String?,
        ),
    ];
  }

  Future<void> addExpense({
    required String userId,
    required int amountCents,
    required String category,
    String? note,
  }) {
    return _client.from('expenses').insert({
      'user_id': userId,
      'amount_cents': amountCents,
      'category': category,
      if (note != null && note.isNotEmpty) 'note': note,
    });
  }

  Future<int?> fetchOverallBudgetCents(String userId) async {
    final row = await _client
        .from('budgets')
        .select('amount_cents')
        .eq('user_id', userId)
        .eq('category', overallBudgetCategory)
        .maybeSingle();
    return row?['amount_cents'] as int?;
  }

  Future<void> setOverallBudget({required String userId, required int amountCents}) {
    return _client.from('budgets').upsert(
      {'user_id': userId, 'category': overallBudgetCategory, 'amount_cents': amountCents},
      onConflict: 'user_id,category',
    );
  }
}
