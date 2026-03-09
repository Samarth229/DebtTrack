import 'package:flutter/material.dart';
import '../../core/models/person.dart';
import '../../core/models/transaction.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/analytics/person_report.dart';
import '../theme/app_theme.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/empty_state.dart';
import 'add_transaction_screen.dart';
import 'transaction_detail_screen.dart';

class PersonDetailScreen extends StatefulWidget {
  final Person person;
  const PersonDetailScreen({super.key, required this.person});

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  final _txnRepo = TransactionRepository();
  final _analytics = AnalyticsService();

  List<TransactionModel> _transactions = [];
  PersonReport? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final txns =
          await _txnRepo.getTransactionsByPersonId(widget.person.id!);
      final reports = await _analytics.getPersonReports();
      final report = reports.firstWhere(
        (r) => r.personId == widget.person.id,
        orElse: () => PersonReport(
          personId: widget.person.id!,
          name: widget.person.name,
          totalCreated: 0,
          totalPaid: 0,
          totalRemaining: 0,
          transactionCount: 0,
          completionRate: 0,
        ),
      );
      setState(() {
        _transactions = txns;
        _report = report;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.person.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Transaction',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddTransactionScreen(
                      preselectedPerson: widget.person),
                ),
              );
              _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    sliver: _transactions.isEmpty
                        ? SliverFillRemaining(
                            child: EmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'No transactions yet',
                              subtitle:
                                  'Tap + to add a transaction with ${widget.person.name}',
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 10),
                                child: TransactionTile(
                                  transaction: _transactions[i],
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            TransactionDetailScreen(
                                          transaction: _transactions[i],
                                          personName: widget.person.name,
                                        ),
                                      ),
                                    );
                                    _load();
                                  },
                                ),
                              ),
                              childCount: _transactions.length,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final p = widget.person;
    final r = _report;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Person info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor:
                        AppTheme.primary.withValues(alpha: 0.12),
                    child: Text(
                      p.name[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        if (p.phone != null) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.phone,
                                size: 14,
                                color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(p.phone!,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600)),
                          ]),
                        ],
                        if (p.upi != null) ...[
                          const SizedBox(height: 4),
                          Row(children: [
                            Icon(Icons.payments,
                                size: 14,
                                color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text(p.upi!,
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600)),
                          ]),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (r != null) ...[
            const SizedBox(height: 10),
            // Financial summary
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceAround,
                      children: [
                        _statItem('Total',
                            '₹${_fmt(r.totalCreated)}',
                            Colors.grey.shade700),
                        _statItem('Paid', '₹${_fmt(r.totalPaid)}',
                            AppTheme.success),
                        _statItem(
                            'Remaining',
                            '₹${_fmt(r.totalRemaining)}',
                            r.totalRemaining > 0
                                ? AppTheme.warning
                                : AppTheme.success),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: r.totalCreated == 0
                            ? 0
                            : r.totalPaid / r.totalCreated,
                        backgroundColor: const Color(0xFFF5F5F5),
                        valueColor: AlwaysStoppedAnimation(
                          r.completionRate >= 100
                              ? AppTheme.success
                              : AppTheme.warning,
                        ),
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${r.completionRate.toStringAsFixed(1)}% collected',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Transactions (${_transactions.length})',
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style:
                TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color)),
      ],
    );
  }

  String _fmt(double v) {
    if (v % 1 == 0) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}
