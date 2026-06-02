import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────
// Configuration for each UPI app
// ─────────────────────────────────────────────────────────────
class _UpiApp {
  final String name;
  final String Function(String params) buildUri; // app-specific deep link
  final Color  bgColor;
  final String label;

  const _UpiApp({
    required this.name,
    required this.buildUri,
    required this.bgColor,
    required this.label,
  });
}

// Each app's deep-link URI format.  All fall back to generic upi:// inside _launch().
final _kApps = <_UpiApp>[
  _UpiApp(
    name: 'Google Pay',
    // Google Pay responds to both gpay:// and tez://
    buildUri: (p) => 'gpay://upi/pay?$p',
    bgColor: const Color(0xFF1A73E8),
    label: 'G',
  ),
  _UpiApp(
    name: 'PhonePe',
    buildUri: (p) => 'phonepe://pay?$p',
    bgColor: const Color(0xFF5F259F),
    label: 'P',
  ),
  _UpiApp(
    name: 'Paytm',
    buildUri: (p) => 'paytmmp://pay?$p',
    bgColor: const Color(0xFF002970),
    label: 'T',
  ),
  _UpiApp(
    name: 'BHIM',
    buildUri: (p) => 'upi://pay?$p',
    bgColor: const Color(0xFF00897B),
    label: 'B',
  ),
];

// ─────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────
Future<void> showUpiPaymentSheet(
  BuildContext context, {
  required String upiId,
  required String payeeName,
  required double amount,
  String? description,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _UpiPaymentSheet(
      upiId: upiId,
      payeeName: payeeName,
      amount: amount,
      description: description,
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Sheet widget
// ─────────────────────────────────────────────────────────────
class _UpiPaymentSheet extends StatelessWidget {
  final String  upiId;
  final String  payeeName;
  final double  amount;
  final String? description;

  const _UpiPaymentSheet({
    required this.upiId,
    required this.payeeName,
    required this.amount,
    this.description,
  });

  // Build the UPI query params
  String get _params {
    final buf = StringBuffer()
      ..write('pa=${Uri.encodeComponent(upiId)}')
      ..write('&pn=${Uri.encodeComponent(payeeName)}')
      ..write('&am=${amount.toStringAsFixed(2)}')
      ..write('&cu=INR');
    if (description != null && description!.trim().isNotEmpty) {
      buf.write('&tn=${Uri.encodeComponent(description!.trim())}');
    }
    return buf.toString();
  }

  // Generic upi:// URI — always works as long as ANY UPI app is installed
  Uri get _genericUri => Uri.parse('upi://pay?$_params');

  Future<void> _launch(BuildContext context, _UpiApp app) async {
    bool launched = false;

    // 1️⃣ Try app-specific deep link
    try {
      final specific = Uri.parse(app.buildUri(_params));
      launched = await launchUrl(specific, mode: LaunchMode.externalApplication);
    } catch (_) {}

    // 2️⃣ Fallback → generic upi:// (lets OS pick any installed UPI app)
    if (!launched) {
      try {
        launched = await launchUrl(_genericUri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No UPI app found. Please install Google Pay, PhonePe or Paytm.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }

    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _launchAny(BuildContext context) async {
    try {
      final ok = await launchUrl(_genericUri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No UPI app found on this device.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20, 16, 20,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ─────────────────────────────────────────
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Amount header ───────────────────────────────────
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: GoogleFonts.outfit(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'to $payeeName',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 10),

          // ── UPI ID pill with Copy ─────────────────────────────────────
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: upiId));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('UPI ID copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    upiId,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // ── Help Note ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'If your bank blocks the direct payment, copy the UPI ID above and pay manually in your app.',
              style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 28),

          // ── Section label ────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'PAY WITH',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey[500],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── 4 app buttons ────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _kApps
                .map((app) => _AppTile(
                      app: app,
                      onTap: () => _launch(context, app),
                    ))
                .toList(),
          ),

          const SizedBox(height: 20),

          // ── Divider ──────────────────────────────────────────
          Row(children: [
            Expanded(child: Divider(color: Colors.grey[200])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('or',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ),
            Expanded(child: Divider(color: Colors.grey[200])),
          ]),
          const SizedBox(height: 14),

          // ── Generic button ───────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _launchAny(context),
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Any UPI App'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[500])),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// App icon tile
// ─────────────────────────────────────────────────────────────
class _AppTile extends StatelessWidget {
  final _UpiApp    app;
  final VoidCallback onTap;

  const _AppTile({required this.app, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: app.bgColor,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: app.bgColor.withOpacity(0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                app.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            app.name,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
