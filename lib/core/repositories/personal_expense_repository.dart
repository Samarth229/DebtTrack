import '../database/database_helper.dart';
import '../models/personal_expense.dart';

class PersonalExpenseRepository {
  final _db = DatabaseHelper();

  Future<int> insert(PersonalExpense expense) async {
    final db = await _db.database;
    return db.insert('personal_expenses', expense.toMap());
  }

  Future<List<PersonalExpense>> getAll() async {
    final db = await _db.database;
    final maps =
        await db.query('personal_expenses', orderBy: 'created_at DESC');
    return maps.map((m) => PersonalExpense.fromMap(m)).toList();
  }

  Future<double> getTotalAmount() async {
    final db = await _db.database;
    final result = await db
        .rawQuery('SELECT SUM(amount) as total FROM personal_expenses');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getThisMonthAmount() async {
    final db = await _db.database;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1).toIso8601String();
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM personal_expenses WHERE created_at >= ?',
      [start],
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
