import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';

final _baht = NumberFormat('#,##0.00', 'th');

DateTime _parseExpiry(String raw) {
  final iso = DateTime.tryParse(raw);
  if (iso != null) return iso.toLocal();
  try {
    final stripped = raw
        .replaceAll(RegExp(r'\s*\([^)]*\)\s*$'), '')
        .replaceFirst('GMT', '')
        .trim();
    return DateFormat(
      'EEE MMM dd yyyy HH:mm:ss Z',
      'en',
    ).parse(stripped).toLocal();
  } catch (_) {
    return DateTime.now().subtract(const Duration(seconds: 1));
  }
}

class PromptPayDialog extends StatefulWidget {
  const PromptPayDialog({
    super.key,
    required this.qrCodeUri,
    required this.grandTotal,
    this.expiresAt,
    required this.onDone,
    this.onExpired,
    this.isPaymentConfirmed,
    this.onPaymentConfirmed,
    this.paymentCheckInterval = const Duration(seconds: 3),
    this.doneLabel = 'ปิด',
  });

  final String qrCodeUri;
  final double grandTotal;
  final String? expiresAt;
  final VoidCallback onDone;
  final FutureOr<void> Function()? onExpired;
  final FutureOr<bool> Function()? isPaymentConfirmed;
  final FutureOr<void> Function()? onPaymentConfirmed;
  final Duration paymentCheckInterval;
  final String doneLabel;

  @override
  State<PromptPayDialog> createState() => _PromptPayDialogState();
}

class _PromptPayDialogState extends State<PromptPayDialog> {
  final _qrKey = GlobalKey();
  late final WebViewController _qrController;
  Timer? _timer;
  Timer? _paymentStatusTimer;
  Duration _remaining = Duration.zero;
  bool _expired = false;
  bool _handledExpired = false;
  bool _checkingPaymentStatus = false;
  bool _handledPaymentConfirmed = false;
  bool _qrLoaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _qrController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _qrLoaded = true);
          },
        ),
      )
      ..loadHtmlString(_buildQrHtml(widget.qrCodeUri));
    _initTimer();
    _initPaymentStatusPolling();
  }

  String _buildQrHtml(String uri) {
    final escapedUri = uri
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');

    return '''
<!doctype html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
    <style>
      html, body {
        width: 100%;
        height: 100%;
        margin: 0;
        padding: 0;
        overflow: hidden;
        background: #ffffff;
      }
      body {
        display: flex;
        align-items: center;
        justify-content: center;
      }
      img {
        display: block;
        width: 100%;
        height: 100%;
        object-fit: contain;
      }
    </style>
  </head>
  <body>
    <img src="$escapedUri" alt="PromptPay QR">
  </body>
</html>
''';
  }

  void _initTimer() {
    if (widget.expiresAt == null) return;
    final expiry = _parseExpiry(widget.expiresAt!);
    final now = DateTime.now();
    if (!expiry.isAfter(now)) {
      _expired = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleExpired());
      return;
    }
    _remaining = expiry.difference(now);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = expiry.difference(DateTime.now());
      if (remaining.isNegative || remaining.inSeconds <= 0) {
        _timer?.cancel();
        if (mounted) {
          setState(() {
            _expired = true;
            _remaining = Duration.zero;
          });
        }
        _handleExpired();
      } else {
        if (mounted) setState(() => _remaining = remaining);
      }
    });
  }

  void _initPaymentStatusPolling() {
    if (widget.isPaymentConfirmed == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPaymentStatus());
    _paymentStatusTimer = Timer.periodic(
      widget.paymentCheckInterval,
      (_) => _checkPaymentStatus(),
    );
  }

  Future<void> _checkPaymentStatus() async {
    if (_checkingPaymentStatus ||
        _handledPaymentConfirmed ||
        _handledExpired ||
        _expired ||
        !mounted) {
      return;
    }

    _checkingPaymentStatus = true;
    try {
      final confirmed = await widget.isPaymentConfirmed!.call();
      if (confirmed && mounted) {
        await _handlePaymentConfirmed();
      }
    } catch (_) {
      // Polling is best-effort; the next interval can recover from a transient
      // network/API error while the user keeps the QR visible.
    } finally {
      _checkingPaymentStatus = false;
    }
  }

  Future<void> _handlePaymentConfirmed() async {
    if (_handledPaymentConfirmed || !mounted) return;
    _handledPaymentConfirmed = true;
    _timer?.cancel();
    _paymentStatusTimer?.cancel();

    final route = ModalRoute.of(context);
    if (route?.isCurrent ?? false) {
      Navigator.of(context).pop();
    }
    await widget.onPaymentConfirmed?.call();
  }

  Future<void> _handleExpired() async {
    if (_handledExpired || !mounted) return;
    _handledExpired = true;
    _paymentStatusTimer?.cancel();
    final route = ModalRoute.of(context);
    if (route?.isCurrent ?? false) {
      Navigator.of(context).pop();
    }
    await widget.onExpired?.call();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _paymentStatusTimer?.cancel();
    super.dispose();
  }

  String _formatRemaining() {
    final mm = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Future<void> _saveQrToGallery() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) return;

      await Gal.putImageBytes(
        byteData.buffer.asUint8List(),
        name: 'promptpay_qr',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึก QR ลงแกลเลอรีแล้ว')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกไม่สำเร็จ กรุณาลองใหม่')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'สแกนจ่าย PromptPay',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'ยอดชำระ ฿${_baht.format(widget.grandTotal)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              // Timer banner — full-width ด้วย CrossAxisAlignment.stretch
              if (widget.expiresAt != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _expired ? Colors.red.shade50 : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _expired
                          ? Colors.red.shade200
                          : Colors.amber.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Icon(
                        _expired
                            ? Icons.timer_off_outlined
                            : Icons.timer_outlined,
                        size: 16,
                        color: _expired
                            ? Colors.red.shade700
                            : Colors.amber.shade800,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _expired
                            ? 'QR หมดอายุแล้ว'
                            : 'เหลือเวลาชำระเงิน ${_formatRemaining()} นาที',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _expired
                              ? Colors.red.shade700
                              : Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Keep the Omise QR image inside a stable, padded viewport.
              if (!_expired) ...[
                LayoutBuilder(
                  builder: (context, constraints) {
                    const qrCardPadding = 5.0;
                    final cardWidth = constraints.maxWidth
                        .clamp(220.0, 320.0)
                        .toDouble();
                    final imageWidth = cardWidth - (qrCardPadding * 2);
                    final imageHeight = imageWidth * 1.32;

                    return Center(
                      child: RepaintBoundary(
                        key: _qrKey,
                        child: Container(
                          width: cardWidth,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(qrCardPadding),
                          child: SizedBox(
                            width: imageWidth,
                            height: imageHeight,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                WebViewWidget(controller: _qrController),
                                if (!_qrLoaded)
                                  const CircularProgressIndicator(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton.icon(
                    onPressed: _saving ? null : _saveQrToGallery,
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined, size: 18),
                    label: Text(
                      _saving ? 'กำลังบันทึก...' : 'บันทึก QR ลงรูปภาพ',
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'เปิดแอปธนาคารแล้วสแกน QR Code\nการชำระเงินจะถูกยืนยันโดยอัตโนมัติ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
              ] else
                const SizedBox(height: 8),
              OutlinedButton(
                onPressed: widget.onDone,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                ),
                child: Text(widget.doneLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
