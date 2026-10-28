import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:dalabapay/presentation/widgets/receipt_share.dart';
import 'package:dalabapay/ui/ui.dart';

void main() {
  test('receipt details from a transaction (Leones) and a PDF', () async {
    final d = ReceiptData.fromTxn({
      'reference': 'PO202610270001ABCD1234',
      'type': 'payout',
      'description': 'Transfer to Fatmata Kamara · Orange Money',
      'amount': 515.1,
      'fee': 0,
      'currency': 'SLE',
      'status': 'success',
      'recipient': '076123456',
      'createdAt': '2026-10-27T10:00:00Z',
      'metadata': {'accountName': 'Fatmata Kamara', 'bankName': 'Orange Money'},
    }, extraRows: const [DPReviewRow('They receive', 'Le 500.00')]);
    expect(d.amount, 'Le 515.10');
    expect(d.providerName, 'Orange');
    expect(d.rows.first.label, 'They receive');
    expect(d.rows.map((r) => r.label), containsAll(['Recipient', 'Account name', 'Reference', 'Date & time']));
    expect(d.fileBase, 'Dalabapay-receipt-PO202610270001ABCD1234');

    // 1x1 PNG
    final png = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
      0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
      0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
      0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);
    final pdf = await receiptPdf(png, d);
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
  });

  test('transfer abroad: the receipt shows both currencies', () {
    final tx = {
      'reference': 'PO202610280002GH',
      'type': 'payout',
      'description': 'Transfer to Kwame Mensah · MTN',
      'amount': 185.44,
      'fee': 0,
      'currency': 'SLE',
      'status': 'success',
      'createdAt': '2026-10-28T10:00:00Z',
      'metadata': {
        'sendCurrency': 'GHS',
        'sendAmount': 100,
        'countryName': 'Ghana',
        'accountName': 'Kwame Mensah',
        'accountNumber': '0241234567',
        'serviceFee': 9.44,
        'rate': 1.8544,
      },
    };
    final d = ReceiptData.fromTxn(tx);
    final rows = {for (final r in d.rows) r.label: r.value};
    expect(rows['You sent'], 'Le 185.44');
    expect(rows['They received'], 'GHS 100.00');
    expect(rows['Country'], 'Ghana');
    expect(rows['Service fee'], 'Le 9.44');
    expect(rows['Rate'], startsWith('1 GHS = Le'));
    expect(currencyMoney(1250, 'KES'), 'KES 1,250.00');
  });
}
