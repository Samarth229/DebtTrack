import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/repositories/personal_expense_repository.dart';
import '../../core/repositories/transaction_repository.dart';
import '../theme/app_theme.dart';
import 'loans_screen.dart';
import 'profile_screen.dart';


class PersonalScreen extends StatefulWidget {
  const PersonalScreen({super.key});

  @override
  State<PersonalScreen> createState() => _PersonalScreenState();
}

class _PersonalScreenState extends State<PersonalScreen> {
  final _repo = PersonalExpenseRepository();
  final _txnRepo = TransactionRepository();

  String? _profileImagePath;

  double _totalSelf = 0;
  double _thisMonth = 0;
  double _pendingGiving = 0;
  double _pendingTaking = 0;
  double _loansGivenTotal = 0;
  double _loansTakenTotal = 0;
  double _splitTotal = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final imgPath = prefs.getString('profile_image');

      final totalSelf = await _repo.getTotalAmount();
      final thisMonth = await _repo.getThisMonthAmount();
      final allTxns = await _txnRepo.getAllTransactions();

      double pendingGiving = 0;
      double pendingTaking = 0;
      double loansGivenTotal = 0;
      double loansTakenTotal = 0;
      double splitTotal = 0;

      for (final t in allTxns) {
        if (t.type == 'loan_giving' || t.type == 'loan') {
          loansGivenTotal += t.totalAmount;
          if (t.status == 'pending') pendingGiving += t.remainingAmount;
        } else if (t.type == 'loan_taking') {
          loansTakenTotal += t.totalAmount;
          if (t.status == 'pending') pendingTaking += t.remainingAmount;
        } else if (t.type == 'split') {
          splitTotal += t.totalAmount;
        }
      }

      setState(() {
        _profileImagePath = imgPath;
        _totalSelf = totalSelf;
        _thisMonth = thisMonth;
        _pendingGiving = pendingGiving;
        _pendingTaking = pendingTaking;
        _loansGivenTotal = loansGivenTotal;
        _loansTakenTotal = loansTakenTotal;
        _splitTotal = splitTotal;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    _load(); // refresh avatar after returning
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personal'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _openProfile,
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: _profileImagePath != null &&
                        File(_profileImagePath!).existsSync()
                    ? FileImage(File(_profileImagePath!))
                    : null,
                child: _profileImagePath == null ||
                        !File(_profileImagePath!).existsSync()
                    ? const Icon(Icons.person, size: 20, color: Colors.white)
                    : null,
              ),
            ),
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
                  _buildSelfCard(),
                  const SizedBox(height: 12),
                  _buildLoansCard(),
                  const SizedBox(height: 12),
                  _buildGraph(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildSelfCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF388E3C), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.success.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Total Self Spend',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            '₹${_fmt(_totalSelf)}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statChip('This Month', '₹${_fmt(_thisMonth)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }

  Widget _buildLoansCard() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoansScreen()),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Pending Loans',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Icon(Icons.chevron_right, size: 18, color: Colors.grey.shade400),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _loanTile(
                      icon: Icons.arrow_upward,
                      label: 'To Collect',
                      subtitle: 'Loans given',
                      amount: _pendingGiving,
                      color: AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _loanTile(
                      icon: Icons.arrow_downward,
                      label: 'To Repay',
                      subtitle: 'Loans taken',
                      amount: _pendingTaking,
                      color: AppTheme.danger,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loanTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required double amount,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text('₹${_fmt(amount)}',
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          Text(subtitle,
              style:
                  TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildGraph() {
    final maxVal = [_totalSelf, _loansGivenTotal, _loansTakenTotal, _splitTotal]
        .reduce((a, b) => a > b ? a : b);

    final bars = [
      _BarData('Self', _totalSelf, AppTheme.success),
      _BarData('Given', _loansGivenTotal, AppTheme.primary),
      _BarData('Taken', _loansTakenTotal, AppTheme.danger),
      _BarData('Split', _splitTotal, AppTheme.splitColor),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Overview',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 20),
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: bars.map((b) {
                  final fraction =
                      maxVal <= 0 ? 0.0 : (b.value / maxVal).clamp(0.0, 1.0);
                  return _buildBar(b, fraction);
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            // Legend
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: bars.map((b) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: b.color,
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 4),
                    Text(b.label,
                        style: const TextStyle(fontSize: 11)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(_BarData bar, double fraction) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text('₹${_fmt(bar.value)}',
            style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          width: 44,
          height: 120 * fraction,
          decoration: BoxDecoration(
            color: bar.color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Text(bar.label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    if (v % 1 == 0) return v.toInt().toString();
    return v.toStringAsFixed(0);
  }
}

class _BarData {
  final String label;
  final double value;
  final Color color;
  _BarData(this.label, this.value, this.color);
}
