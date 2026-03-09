import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/personal_expense.dart';
import '../../core/repositories/personal_expense_repository.dart';
import 'dashboard_screen.dart';
import 'people_screen.dart';
import 'transactions_screen.dart';
import 'personal_screen.dart';
import 'add_person_screen.dart';
import 'add_transaction_screen.dart';
import 'repay_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  static const _gpayChannel = MethodChannel('com.example.myfinance/gpay');
  final _personalRepo = PersonalExpenseRepository();

  int _tab = 0;
  int _refreshKey = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check for any pending actions/expenses from PaymentDialogActivity
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPending());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPending();
    }
  }

  Future<void> _checkPending() async {
    await _commitPendingPersonalExpenses();
    await _handlePendingAction();
  }

  /// Reads amounts saved by PaymentDialogActivity (Self option) and commits to DB
  Future<void> _commitPendingPersonalExpenses() async {
    try {
      final raw = await _gpayChannel.invokeMethod<String>('getPendingPersonalExpenses') ?? '';
      if (raw.isNotEmpty) {
        for (final part in raw.split(',')) {
          final amount = double.tryParse(part.trim());
          if (amount != null && amount > 0) {
            await _personalRepo.insert(PersonalExpense(
              amount: amount,
              source: 'gpay_self',
              createdAt: DateTime.now(),
            ));
          }
        }
        setState(() => _refreshKey++);
      }
    } catch (_) {}
  }

  /// Reads pending action (split / loan / repay) set by PaymentDialogActivity
  Future<void> _handlePendingAction() async {
    try {
      final action = await _gpayChannel.invokeMethod<String?>('getPendingAction');
      if (action != null && mounted) {
        if (action == 'repay') {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RepayScreen()),
          );
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddTransactionScreen(
                preselectedType: action == 'loan' ? 'loan' : 'split',
              ),
            ),
          );
        }
        setState(() => _refreshKey++);
      }
    } catch (_) {}
  }

  List<Widget> get _screens => [
        DashboardScreen(
          key: ValueKey('dash_$_refreshKey'),
          onGPayLaunched: _onGPayLaunched,
        ),
        PeopleScreen(key: ValueKey('people_$_refreshKey')),
        TransactionsScreen(key: ValueKey('txn_$_refreshKey')),
        PersonalScreen(key: ValueKey('personal_$_refreshKey')),
      ];

  void _onGPayLaunched() {
    // Will be caught on resume via _handlePendingAction or in-app popup
  }

  void _onAdd() async {
    if (_tab == 1) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddPersonScreen()),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
      );
    }
    setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'People',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Personal',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAdd,
        tooltip: _tab == 1 ? 'Add Person' : 'Add Transaction',
        child: const Icon(Icons.add),
      ),
    );
  }
}

