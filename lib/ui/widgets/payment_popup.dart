import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum PaymentChoice { self, split, loan, noPayment }

Future<PaymentChoice?> showPaymentPopup(BuildContext context) {
  return showDialog<PaymentChoice>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _PaymentPopup(),
  );
}

class _PaymentPopup extends StatelessWidget {
  const _PaymentPopup();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Column(
        children: [
          Icon(Icons.payment, color: AppTheme.primary, size: 40),
          SizedBox(height: 8),
          Text('Payment recorded for?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _option(
            context,
            icon: Icons.person,
            label: 'Self',
            subtitle: 'Just for me — personal expense',
            color: AppTheme.success,
            value: PaymentChoice.self,
          ),
          const SizedBox(height: 10),
          _option(
            context,
            icon: Icons.group,
            label: 'Split',
            subtitle: 'Share with others',
            color: AppTheme.splitColor,
            value: PaymentChoice.split,
          ),
          const SizedBox(height: 10),
          _option(
            context,
            icon: Icons.handshake_outlined,
            label: 'Loan',
            subtitle: 'Give or take a loan',
            color: AppTheme.loanColor,
            value: PaymentChoice.loan,
          ),
          const SizedBox(height: 10),
          _option(
            context,
            icon: Icons.cancel_outlined,
            label: 'No Payment',
            subtitle: 'I didn\'t actually pay',
            color: Colors.grey,
            value: PaymentChoice.noPayment,
          ),
        ],
      ),
    );
  }

  Widget _option(BuildContext context,
      {required IconData icon,
      required String label,
      required String subtitle,
      required Color color,
      required PaymentChoice value}) {
    return InkWell(
      onTap: () => Navigator.pop(context, value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                          fontSize: 14)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}
