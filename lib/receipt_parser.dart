// lib/receipt_parser.dart

import 'dart:core'; // List kullanımı için eklenmiş

/// Represents the extracted data from a receipt.
class ReceiptData {
  String? date;
  double? totalAmount;
  List<String>? items;

  ReceiptData({this.date, this.totalAmount, this.items});

  @override
  String toString() {
    return 'ReceiptData(\n'
        '  date: $date,\n'
        '  totalAmount: $totalAmount,\n'
        '  items: $items,\n'
        ')';
  }
}

/// Parses the raw text from a receipt image and extracts relevant data.
ReceiptData parseReceiptText(String rawText) {

  final receiptData = ReceiptData(items: []); // Initialize with empty items list

  // Simple regex for date formats (dd.mm.yyyy, yyyy-mm-dd)
  final dateRegex = RegExp(r'\d{2}\.\d{2}\.\d{4}|\d{4}-\d{2}-\d{2}');
  final dateMatch = dateRegex.firstMatch(rawText);
  if (dateMatch != null) {
    receiptData.date = dateMatch.group(0);
  }

  // Simple regex for total amount (looks for numbers after keywords or currency symbols)
  final totalRegex = RegExp(r'(?:Total|TOPLAM|TL|€|\$)\s*([\d.,]+)');
  final totalMatch = totalRegex.firstMatch(rawText);
  if (totalMatch != null) {
    try {
      receiptData.totalAmount = double.tryParse(totalMatch.group(1)!.replaceAll(',', '.'));
    } catch (e) {
      // print('Error parsing total amount: $e'); // Bu satır kaldırıldı veya yorum satırı yapıldı
    }
  }

  return receiptData;
}
