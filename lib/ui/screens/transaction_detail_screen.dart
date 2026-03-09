import 'package:flutter/material.dart';
import '../../core/models/transaction.dart';
import '../../core/models/payment.dart';
import '../../core/repositories/transaction_repository.dart';
import '../../core/services/transaction_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;
  final String? personName;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    this.personName,
  });

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState
    extends State<TransactionDetailScreen> {
  final _txnRepo = TransactionRepository();
  final _txnService = TransactionService();

  List<Payment> _payments = [];
  late TransactionModel _transaction;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _transaction = widget.transaction;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final payments = await _txnRepo
          .getPaymentsByTransactionId(_transaction.id!);
      final updated =
          await _txnRepo.getTransactionById(_transaction.id!);
      setState(() {
        _payments = payments;
        if (updated != null) _transaction = updated;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _showPaymentDialog() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remaining: ₹${_fmt(_transaction.remainingAmount)}',
              style: TextStyle(
                  color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                minimumSize: const Size(80, 40)),
            child: const Text('Record'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final amount = double.tryParse(controller.text.trim());
    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Enter a valid amount'),
              backgroundColor: Colors.orange),
        );
      }
      return;
    }

    try {
      await _txnService.recordPayment(
          transactionId: _transaction.id!, amount: amount);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Payment recorded'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _transaction;
    final isCompleted = t.status == 'completed';
    final paid = t.totalAmount - t.remainingAmount;
    final progress =
        t.totalAmount == 0 ? 0.0 : paid / t.totalAmount;
    final typeColor =
        t.type == 'loan' ? AppTheme.loanColor : AppTheme.splitColor;
    final statusColor =
        isCompleted ? AppTheme.success : AppTheme.warning;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Detail'),
        actions: [
          if (!isCompleted)
            TextButton.icon(
              onPressed: _showPaymentDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Pay',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Main card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              _chip(t.type.toUpperCase(), typeColor),
                              _chip(
                                  isCompleted ? 'PAID' : 'PENDING',
                                  statusColor),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '₹${_fmt(t.totalAmount)}',
                            style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          if (widget.personName != null)
                            Text(
                              widget.personName!,
                              style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade600),
                            ),
                          const SizedBox(height: 20),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor:
                                  const Color(0xFFF5F5F5),
                              valueColor: AlwaysStoppedAnimation(
                                  statusColor),
                              minHeight: 12,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceAround,
                            children: [
                              _statItem('Total',
                                  '₹${_fmt(t.totalAmount)}',
                                  Colors.grey.shade700),
                              _statItem('Paid', '₹${_fmt(paid)}',
                                  AppTheme.success),
                              _statItem(
                                  'Remaining',
                                  '₹${_fmt(t.remainingAmount)}',
                                  t.remainingAmount > 0
                                      ? AppTheme.warning
                                      : AppTheme.success),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Created on ${_formatDate(t.createdAt)}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Payment History (${_payments.length})',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                      if (!isCompleted)
                        TextButton.icon(
                          onPressed: _showPaymentDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Record'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_payments.isEmpty)
                    EmptyState(
                      icon: Icons.payment,
                      title: 'No payments yet',
                      subtitle: isCompleted
                          ? null
                          : 'Tap Record to add a payment',
                    )
                  else
                    ..._payments.map(
                      (pay) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.success
                                  .withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.check,
                                color: AppTheme.success, size: 20),
                          ),
                          title: Text(
                            '₹${_fmt(pay.amount)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            _formatDate(pay.createdAt),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: isCompleted
          ? null
          : FloatingActionButton.extended(
              onPressed: _showPaymentDialog,
              icon: const Icon(Icons.add),
              label: const Text('Record Payment'),
            ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color)),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, color: Colors.grey.shade500)),
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

  String _formatDate(DateTime dt) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${m[dt.month - 1]} ${dt.year}';
  }
}
