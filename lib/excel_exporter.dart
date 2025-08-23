// lib/excel_exporter.dart

import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:myapp/receipt_parser.dart';

/// Exports a list of ReceiptData objects to an Excel file in Uint8List format.
Future<Uint8List?> exportReceiptsToExcel(List<ReceiptData> receipts) async {
  try {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];

    // Add headers
    sheet.appendRow(['Date', 'Total Amount', 'Items']);

    // Write data rows
    for (final receipt in receipts) {
      sheet.appendRow([
        receipt.date ?? '',
        receipt.totalAmount ?? '',
        receipt.items?.join(', ') ?? '', // Join items with comma for simplicity
      ]);
    }

    // Save the workbook and return as Uint8List
    final Uint8List? excelBytes = excel.encode() as Uint8List?;
    return excelBytes;
  } catch (e) {
        return null; // Return null in case of error
  }
}