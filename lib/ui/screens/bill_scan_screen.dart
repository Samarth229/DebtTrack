import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../theme/app_theme.dart';
import 'bill_items_screen.dart';

// ── Bill Parser ──────────────────────────────────────────────────────────────

class ParsedBillItem {
  String name;
  double price;
  ParsedBillItem({required this.name, required this.price});
}

class BillParser {
  static const _skip = [
    'total', 'subtotal', 'sub total', 'grand total', 'net total',
    'tax', 'gst', 'sgst', 'cgst', 'igst', 'vat', 'service charge',
    'service tax', 'discount', 'bill', 'invoice', 'receipt', 'thank',
    'welcome', 'please', 'visit', 'again', 'table', 'order', 'qty',
    'item', 'price', 'amount', 'rate', 'mrp', 'cash', 'change',
    'paid', 'balance', 'due',
  ];

  static List<ParsedBillItem> parse(String rawText) {
    final lines = rawText.split('\n');
    final items = <ParsedBillItem>[];
    final priceRegex = RegExp(r'(\d+(?:[.,]\d{1,2})?)(?:\s*)$');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.length < 3) continue;

      final lower = trimmed.toLowerCase();
      if (_skip.any((s) => lower.contains(s))) continue;

      final match = priceRegex.firstMatch(trimmed);
      if (match == null) continue;

      final priceStr = match.group(1)!.replaceAll(',', '.');
      final price = double.tryParse(priceStr);
      if (price == null || price <= 0 || price > 99999) continue;

      final nameEnd = trimmed.lastIndexOf(match.group(0)!);
      var name = trimmed.substring(0, nameEnd).trim();
      // Remove leading quantity like "1x", "2 x", "1."
      name = name.replaceFirst(RegExp(r'^\d+\s*[x.]?\s*'), '').trim();
      if (name.length < 2) continue;

      items.add(ParsedBillItem(name: name, price: price));
    }

    return items;
  }
}

// ── Bill Scan Screen ─────────────────────────────────────────────────────────

class BillScanScreen extends StatefulWidget {
  final String type;
  const BillScanScreen({super.key, required this.type});

  @override
  State<BillScanScreen> createState() => _BillScanScreenState();
}

class _BillScanScreenState extends State<BillScanScreen> {
  bool _scanning = false;
  List<ParsedBillItem>? _parsedItems;
  bool _editMode = false;

  Future<void> _scanBill() async {
    setState(() => _scanning = true);
    try {
      final picker = ImagePicker();
      final XFile? image =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 90);

      if (image == null) {
        setState(() => _scanning = false);
        return;
      }

      // OCR
      final inputImage = InputImage.fromFilePath(image.path);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognized = await recognizer.processImage(inputImage);
      await recognizer.close();

      // Auto-delete image
      final file = File(image.path);
      if (await file.exists()) await file.delete();

      final items = BillParser.parse(recognized.text);

      setState(() {
        _parsedItems = items;
        _scanning = false;
        _editMode = false;
      });
    } catch (e) {
      setState(() => _scanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onConfirm() {
    if (_parsedItems == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BillItemsScreen(
          type: widget.type,
          initialItems: _parsedItems!
              .map((i) => BillItemEntry(name: i.name, basePrice: i.price))
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Bill')),
      body: _scanning
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Extracting bill items...'),
                ],
              ),
            )
          : _parsedItems == null
              ? _buildInitial()
              : _buildConfirm(),
    );
  }

  Widget _buildInitial() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.document_scanner_outlined,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            const Text('Take a photo of the bill',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'Items and prices will be extracted automatically.\nThe photo is deleted immediately after scanning.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _scanBill,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Open Camera'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirm() {
    final items = _parsedItems!;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt, color: AppTheme.primary),
                  const SizedBox(width: 8),
                  Text('${items.length} items extracted',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 12),
              ...items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: _editMode
                        ? Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  decoration: const InputDecoration(
                                      labelText: 'Item name', isDense: true),
                                  controller: TextEditingController(
                                      text: item.name)
                                    ..selection = TextSelection.collapsed(
                                        offset: item.name.length),
                                  onChanged: (v) => items[i].name = v,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  decoration: const InputDecoration(
                                      labelText: '₹ Price', isDense: true),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  controller: TextEditingController(
                                      text: item.price.toString()),
                                  onChanged: (v) {
                                    final p = double.tryParse(v);
                                    if (p != null) items[i].price = p;
                                  },
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(item.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500)),
                              ),
                              Text('₹${item.price.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                            ],
                          ),
                  ),
                );
              }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Is this correct?',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() => _editMode = !_editMode);
                      },
                      icon: Icon(_editMode ? Icons.check : Icons.edit, size: 18),
                      label: Text(_editMode ? 'Done Editing' : 'No, Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _editMode ? null : _onConfirm,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Yes, Continue'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _scanBill,
                child: const Text('Rescan Bill'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
