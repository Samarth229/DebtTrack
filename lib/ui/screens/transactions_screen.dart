import 'package:flutter/material.dart';
import '../../core/models/transaction.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/repositories/person_repository.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/empty_state.dart';
import 'transaction_detail_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _txnRepo = TransactionRepository();
  final _personRepo = PersonRepository();

  List<TransactionModel> _all = [];
  List<TransactionModel> _filtered = [];
  Map<int, String> _personNames = {};
  bool _loading = true;
  String _statusFilter = 'all';
  String _typeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final txns = await _txnRepo.getAllTransactions();
      final persons = await _personRepo.getAllPersons();
      setState(() {
        _all = txns;
        _personNames = {for (final p in persons) p.id!: p.name};
        _filtered = _computeFiltered(txns);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<TransactionModel> _computeFiltered(List<TransactionModel> src) {
    return src.where((t) {
      final statusOk = _statusFilter == 'all' || t.status == _statusFilter;
      final isLoanType = t.type == 'loan' ||
          t.type == 'loan_giving' ||
          t.type == 'loan_taking';
      final typeOk = _typeFilter == 'all' ||
          (_typeFilter == 'loan' && isLoanType) ||
          (_typeFilter == 'split' && t.type == 'split');
      return statusOk && typeOk;
    }).toList();
  }

  void _applyFilter() {
    setState(() => _filtered = _computeFiltered(_all));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transactions${_all.isNotEmpty ? ' (${_all.length})' : ''}'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                _chip('All', _statusFilter == 'all', () {
                  _statusFilter = 'all';
                  _applyFilter();
                }),
                const SizedBox(width: 8),
                _chip('Pending', _statusFilter == 'pending', () {
                  _statusFilter = 'pending';
                  _applyFilter();
                }),
                const SizedBox(width: 8),
                _chip('Paid', _statusFilter == 'completed', () {
                  _statusFilter = 'completed';
                  _applyFilter();
                }),
                const SizedBox(width: 16),
                _chip('Loan', _typeFilter == 'loan', () {
                  _typeFilter =
                      _typeFilter == 'loan' ? 'all' : 'loan';
                  _applyFilter();
                }),
                const SizedBox(width: 8),
                _chip('Split', _typeFilter == 'split', () {
                  _typeFilter =
                      _typeFilter == 'split' ? 'all' : 'split';
                  _applyFilter();
                }),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
              ? EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: _all.isEmpty
                      ? 'No transactions yet'
                      : 'No results',
                  subtitle: _all.isEmpty
                      ? 'Create a transaction to get started'
                      : 'Try changing the filters',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final t = _filtered[i];
                      return TransactionTile(
                        transaction: t,
                        personName: _personNames[t.personId],
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TransactionDetailScreen(
                                transaction: t,
                                personName: _personNames[t.personId],
                              ),
                            ),
                          );
                          _load();
                        },
                      );
                    },
                  ),
                ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? Colors.white : Colors.white60),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? const Color(0xFF3F51B5)
                : Colors.white,
          ),
        ),
      ),
    );
  }
}
