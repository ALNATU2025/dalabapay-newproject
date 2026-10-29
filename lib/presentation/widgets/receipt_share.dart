// lib/presentation/widgets/receipt_share.dart
// Share a receipt as a picture (PNG) or save it as a PDF, for every
// payment and transfer (Nigeria and Sierra Leone). The receipt is drawn
// off-screen in the brand's light style, captured, then handed to the
// phone's share sheet (WhatsApp, Gallery, Files / Downloads, Drive…).
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/api/api.dart';
import '../../core/download/download.dart';
import '../../core/format.dart';
import '../../ui/ui.dart';
import 'transaction_widgets.dart';

/// "GHS 1,250.00" for any currency code (Naira and Leones with their signs).
String currencyMoney(num? value, String code) {
  if (code == 'NGN' || code == 'SLE') return DP.moneyIn(value, code);
  return '$code ${DP.moneyIn(value, 'NGN').replaceFirst('₦', '')}';
}

class ReceiptData {
  final String title;
  final String amount;
  final String status; // Successful / Pending / Failed …
  final DateTime date;
  final String reference;
  final List<DPReviewRow> rows;

  /// Provider logo asset (MTN, DStv…), or a provider name to print.
  final String? providerAsset;
  final String? providerName;

  const ReceiptData({
    required this.title,
    required this.amount,
    required this.status,
    required this.date,
    required this.reference,
    required this.rows,
    this.providerAsset,
    this.providerName,
  });

  /// From a transaction (API JSON). [extraRows] come first (e.g. the rows
  /// the payment screen showed).
  /// Transfers abroad: both currencies (what was paid and what arrives).
  static List<DPReviewRow> transferRows(Map<String, dynamic> tx) {
    final m = asMap(tx['metadata']);
    final code = str(m['sendCurrency']);
    if (code.isEmpty || m['sendAmount'] == null) return const [];
    final mine = txCurrency(tx);
    final status = str(tx['status']);
    final rows = <DPReviewRow>[
      DPReviewRow('You sent', txMoney(tx, toDouble(tx['amount']))),
      DPReviewRow(status == 'success' ? 'They received' : 'They receive', currencyMoney(toDouble(m['sendAmount']), code)),
    ];
    if (str(m['countryName']).isNotEmpty) rows.add(DPReviewRow('Country', str(m['countryName'])));
    if (m['accountNumber'] != null) rows.add(DPReviewRow('Account number', str(m['accountNumber'])));
    if (m['serviceFee'] != null) rows.add(DPReviewRow('Service fee', txMoney(tx, toDouble(m['serviceFee']))));
    if (m['rate'] != null && code != mine) rows.add(DPReviewRow('Rate', '1 $code = ${txMoney(tx, toDouble(m['rate']))}'));
    return rows;
  }

  factory ReceiptData.fromTxn(Map<String, dynamic> tx, {String? title, List<DPReviewRow> extraRows = const []}) {
    final meta = asMap(tx['metadata']);
    final amount = toDouble(tx['amount']);
    final fee = toDouble(tx['fee']);
    final description = str(tx['description'], transactionTypeLabel(str(tx['type'])));
    final name = title ?? description;
    final seen = extraRows.map((r) => r.label.toLowerCase()).toSet();
    void add(List<DPReviewRow> out, String label, String? value) {
      if (value == null || value.isEmpty || seen.contains(label.toLowerCase())) return;
      seen.add(label.toLowerCase());
      out.add(DPReviewRow(label, value));
    }

    final rows = <DPReviewRow>[...extraRows.where((r) => !r.strong)];
    for (final r in transferRows(tx)) {
      add(rows, r.label, r.value);
    }
    add(rows, 'Type', transactionTypeLabel(str(tx['type'])));
    add(rows, 'Recipient', tx['recipient']?.toString());
    add(rows, 'Customer', meta['customerName']?.toString());
    add(rows, 'Account name', meta['accountName']?.toString());
    add(rows, 'Bank', meta['bankName']?.toString());
    add(rows, 'Plan', meta['plan']?.toString());
    add(rows, 'Token', meta['token']?.toString());
    add(rows, 'Units', meta['units']?.toString());
    for (final p in asList(meta['pins'])) {
      rows.add(DPReviewRow('PIN', '${p['pin']}${p['serial'] != null ? ' (S/N ${p['serial']})' : ''}'));
    }
    if (fee > 0) add(rows, 'Fee', txMoney(tx, fee));
    add(rows, 'Date & time', dateTimeLabel(parseDate(tx['createdAt'])));
    add(rows, 'Reference', str(tx['reference']));
    final lookup = '$name ${meta['provider'] ?? ''} ${meta['network'] ?? ''} ${meta['operator'] ?? ''}';
    return ReceiptData(
      title: name,
      amount: txMoney(tx, txIsCredit(tx) ? amount : amount + fee),
      status: DPStatus.labelFor(tx['status'] as String?),
      date: parseDate(tx['createdAt']),
      reference: str(tx['reference']),
      rows: rows,
      providerAsset: DPAssets.providerFor(lookup),
      providerName: _slProvider(lookup),
    );
  }

  static String? _slProvider(String s) {
    final l = s.toLowerCase();
    for (final n in const ['Orange', 'Africell', 'Qcell', 'EDSA']) {
      if (l.contains(n.toLowerCase())) return n;
    }
    return null;
  }

  String get fileBase => 'Dalabapay-receipt-${reference.isEmpty ? date.millisecondsSinceEpoch : reference}';
}

// ── Drawing ─────────────────────────────────────────────────

const _ink = Color(0xFF10255A);
const _muted = Color(0xFF7B87A1);
const _line = Color(0xFFE6ECF3);
const _bg = Color(0xFFF7F9FC);

class _ReceiptPicture extends StatelessWidget {
  final ReceiptData d;
  const _ReceiptPicture(this.d);

  Color get _statusColor {
    final s = d.status.toLowerCase();
    if (s.contains('success')) return DP.green;
    if (s.contains('pend') || s.contains('process')) return const Color(0xFFE0A100);
    return DP.red;
  }

  @override
  Widget build(BuildContext context) {
    Widget provider() {
      if (d.providerAsset != null) {
        return Image.asset(d.providerAsset!, width: 44, height: 44, fit: BoxFit.contain);
      }
      if (d.providerName != null) {
        return FittedBox(child: Text(d.providerName!, style: const TextStyle(fontWeight: FontWeight.w900, color: _ink)));
      }
      return const Icon(DPIcons.receipt, color: DP.navyIcon, size: 28);
    }

    return Material(
      color: _bg,
      child: Container(
        width: 400,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DPWordmark(height: 30, light: false),
            const SizedBox(height: 6),
            const Text('Transaction receipt', style: TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 18),
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 32),
                  padding: const EdgeInsets.fromLTRB(16, 44, 16, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _line),
                  ),
                  child: Column(
                    children: [
                      Text(d.title, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 13.5)),
                      const SizedBox(height: 4),
                      Text(d.amount, style: const TextStyle(color: _ink, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                        child: Text(d.status, style: TextStyle(color: _statusColor, fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < d.rows.length; i++) ...[
                        if (i > 0) const Divider(height: 1, color: _line),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.rows[i].label, style: const TextStyle(color: _muted, fontSize: 13)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  d.rows[i].value,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(color: _ink, fontSize: 13, fontWeight: d.rows[i].strong ? FontWeight.w800 : FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: 66,
                  height: 66,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _line, width: 2),
                  ),
                  child: ClipOval(child: Center(child: provider())),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const DPLogoMark(size: 28),
            const SizedBox(height: 6),
            const Text('Thank you for using Dalabapay', style: TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('Generated ${dateTimeLabel(DateTime.now())}', style: const TextStyle(color: _muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// Draws the receipt off-screen and returns it as PNG bytes.
Future<Uint8List?> renderReceiptPng(BuildContext context, ReceiptData d) async {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return null;
  // Logos must be decoded before the picture is taken.
  for (final a in [DPAssets.wordmark, DPAssets.mark, if (d.providerAsset != null) d.providerAsset!]) {
    try {
      await precacheImage(AssetImage(a), context);
    } catch (_) {}
  }
  final key = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -10000,
      top: 0,
      child: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.noScaling),
        child: RepaintBoundary(key: key, child: _ReceiptPicture(d)),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    // Two frames: lay out, then paint.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  } finally {
    entry.remove();
  }
}

/// A one-page PDF with the receipt picture.
Future<Uint8List> receiptPdf(Uint8List png, ReceiptData d) async {
  final doc = pw.Document(title: 'Dalabapay receipt ${d.reference}', author: 'Dalabapay');
  final img = pw.MemoryImage(png);
  doc.addPage(
    pw.Page(
      pageFormat: pdf.PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => pw.Center(child: pw.Image(img, fit: pw.BoxFit.contain)),
    ),
  );
  return doc.save();
}

Future<void> _share(BuildContext context, Uint8List bytes, String name, String mime, ReceiptData d) async {
  // Website: download the file (most desktop browsers can't share files).
  if (kIsWeb && await downloadBytes(bytes, name, mime)) {
    if (context.mounted) dpSnack(context, 'Receipt downloaded', success: true);
    return;
  }
  if (!context.mounted) return;
  final box = context.findRenderObject() as RenderBox?;
  await Share.shareXFiles(
    [XFile.fromData(bytes, name: name, mimeType: mime)],
    subject: 'Dalabapay receipt ${d.reference}',
    sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
  );
}

/// Share as a picture (PNG).
Future<void> shareReceiptImage(BuildContext context, ReceiptData d) async {
  final png = await renderReceiptPng(context, d);
  if (!context.mounted) return;
  if (png == null) {
    dpSnack(context, 'Couldn\'t create the receipt picture. Please try again.', error: true);
    return;
  }
  await _share(context, png, '${d.fileBase}.png', 'image/png', d);
}

/// Save / share as a PDF (choose "Save to device" or Files to download).
Future<void> shareReceiptPdf(BuildContext context, ReceiptData d) async {
  final png = await renderReceiptPng(context, d);
  if (!context.mounted) return;
  if (png == null) {
    dpSnack(context, 'Couldn\'t create the PDF. Please try again.', error: true);
    return;
  }
  final bytes = await receiptPdf(png, d);
  if (!context.mounted) return;
  await _share(context, bytes, '${d.fileBase}.pdf', 'application/pdf', d);
}

/// Bottom sheet: share as picture, download PDF, or share as text.
Future<void> showReceiptShareOptions(BuildContext context, ReceiptData d, {String? text}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: DP.bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(DP.rXl))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DPSheetHandle(),
            const SizedBox(height: 8),
            Text('Share receipt', style: DP.title),
            const SizedBox(height: 8),
            DPMenuRow(
              icon: Icons.image_outlined,
              title: 'Share as picture',
              subtitle: 'WhatsApp, Gallery and more',
              onTap: () async {
                Navigator.pop(ctx);
                await _busy(context, () => shareReceiptImage(context, d));
              },
            ),
            DPMenuRow(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Download PDF',
              subtitle: 'Save to your phone or share',
              onTap: () async {
                Navigator.pop(ctx);
                await _busy(context, () => shareReceiptPdf(context, d));
              },
            ),
            if (text != null)
              DPMenuRow(
                icon: DPIcons.copy,
                title: 'Share as text',
                onTap: () {
                  Navigator.pop(ctx);
                  Share.share(text, subject: 'Dalabapay receipt ${d.reference}');
                },
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _busy(BuildContext context, Future<void> Function() f) async {
  if (!context.mounted) return;
  dpSnack(context, 'Preparing receipt…');
  try {
    await f();
  } catch (e) {
    if (context.mounted) dpSnack(context, errorMessage(e), error: true);
  }
}
