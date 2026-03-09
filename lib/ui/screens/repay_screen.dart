import 'package:flutter/material.dart';
import '../../core/models/person.dart';
import '../../core/repositories/person_repository.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/services/transaction_service.dart';
import '../theme/app_theme.dart';

class RepayScreen extends StatefulWidget {
  const RepayScreen({super.key});

  @override
  State<RepayScreen> createState() => _RepayScreenState();
}

class _RepayScreenState extends State<RepayScreen> {
  final _amountCtrl = TextEditingController();
  final _personRepo = PersonRepository();
  final _txnRepo = TransactionRepository();
  final _txnService = TransactionService();

  // person → pending total (split + loan_giving)
  List<_PersonDue> _dues = [];
  int? _selectedPersonId;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final persons = await _personRepo.getAllPersons();
      final result = <_PersonDue>[];

      for (final p in persons) {
        final splitTxns = await _txnRepo.getPendingByPersonAndTypes(
            p.id!, ['split']);
        final loanTxns = await _txnRepo.getPendingByPersonAndTypes(
            p.id!, ['loan_giving', 'loan']);

        final splitTotal =
            splitTxns.fold<double>(0, (s, t) => s + t.remainingAmount);
        final loanTotal =
            loanTxns.fold<double>(0, (s, t) => s + t.remainingAmount);

        if (splitTotal > 0 || loanTotal > 0) {
          result.add(_PersonDue(
            person: p,
            splitPending: splitTotal,
            loanPending: loanTotal,
          ));
        }
      }

      setState(() {
        _dues = result;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      _showMsg('Enter a valid amount');
      return;
    }
    if (_selectedPersonId == null) {
      _showMsg('Select a person');
      return;
    }

    setState(() => _saving = true);
    try {
      await _txnService.applyRepayment(
          personId: _selectedPersonId!, amount: amount);
      if (mounted) _showSuccess();
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) _showMsg('Error: $e');
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
  }

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.black, width: 1.8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 28),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 550),
            curve: Curves.elasticOut,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 100),
                SizedBox(height: 18),
                Text(
                  'Remaining dues cleared\nfor the Entered Amount',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF212121),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        Navigator.of(context)
          ..pop() // close success dialog
          ..pop(); // close repay screen
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Repay')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _sectionLabel('AMOUNT'),
                const SizedBox(height: 10),
                _borderedCard(
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Enter Amount (₹)',
                      prefixIcon: Icon(Icons.currency_rupee),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _sectionLabel('SELECT PERSON'),
                const SizedBox(height: 10),
                if (_dues.isEmpty)
                  _borderedCard(
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'No pending dues found.\nAdd split or loan transactions first.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ..._dues.map(_personDueTile),
                const SizedBox(height: 28),
                _saving
                    ? const Center(child: CircularProgressIndicator())
                    : _borderedButton(
                        label: 'Update',
                        icon: Icons.check,
                        color: AppTheme.success,
                        onTap: _submit,
                      ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _personDueTile(_PersonDue due) {
    final selected = _selectedPersonId == due.person.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedPersonId = due.person.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.loanColor.withValues(alpha: 0.07)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppTheme.loanColor : Colors.black,
            width: selected ? 2 : 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? AppTheme.loanColor : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppTheme.loanColor : Colors.grey.shade400,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.loanColor.withValues(alpha: 0.12),
              child: Text(
                due.person.name[0].toUpperCase(),
                style: const TextStyle(
                    color: AppTheme.loanColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(due.person.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Row(
                    children: [
                      if (due.splitPending > 0)
                        _dueChip(
                            'Split ₹${_fmt(due.splitPending)}',
                            AppTheme.splitColor),
                      if (due.splitPending > 0 && due.loanPending > 0)
                        const SizedBox(width: 6),
                      if (due.loanPending > 0)
                        _dueChip(
                            'Loan ₹${_fmt(due.loanPending)}',
                            AppTheme.loanColor),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              '₹${_fmt(due.splitPending + due.loanPending)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.danger),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dueChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _borderedCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: child,
    );
  }

  Widget _borderedButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.grey,
            letterSpacing: 0.8),
      );

  String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    if (v % 1 == 0) return v.toInt().toString();
    return v.toStringAsFixed(0);
  }
}

class _PersonDue {
  final Person person;
  final double splitPending;
  final double loanPending;
  _PersonDue(
      {required this.person,
      required this.splitPending,
      required this.loanPending});
}
