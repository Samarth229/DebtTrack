import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  /// Called when GPay is launched so AppShell can track it
  final VoidCallback? onGPayLaunched;
  const QrScannerScreen({super.key, this.onGPayLaunched});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _detected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;
    final raw = barcode.rawValue ?? '';
    if (raw.isEmpty) return;

    // Only handle UPI QR codes
    if (!raw.toLowerCase().startsWith('upi://')) return;

    setState(() => _detected = true);
    _controller.stop();
    _showUpiBottomSheet(raw);
  }

  void _showUpiBottomSheet(String upiString) {
    final uri = Uri.tryParse(upiString);
    final pa = uri?.queryParameters['pa'] ?? '';
    final pn = uri?.queryParameters['pn'] ?? 'Merchant';
    final am = uri?.queryParameters['am'] ?? '';

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code,
                      color: Colors.green, size: 28),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('UPI QR Detected',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(pa,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            _infoRow('Payee', pn),
            if (am.isNotEmpty) _infoRow('Amount', '₹$am'),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _launchGPay(upiString);
                      if (mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open GPay'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _detected = false);
      _controller.start();
    });
  }

  Future<void> _launchGPay(String upiString) async {
    widget.onGPayLaunched?.call();
    // Try GPay-specific scheme first, fall back to generic UPI
    final gpayUri = Uri.parse(
        upiString.replaceFirst('upi://', 'gpay://upi/'));
    final upiUri = Uri.parse(upiString);

    if (await canLaunchUrl(gpayUri)) {
      await launchUrl(gpayUri);
    } else if (await canLaunchUrl(upiUri)) {
      await launchUrl(upiUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('GPay not found. Please install GPay.'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('$label: ',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Scan QR Code',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay with scanning frame
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primary, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                'Point camera at a UPI / GPay QR code',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
