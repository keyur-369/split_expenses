import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_upi_india/flutter_upi_india.dart' show UpiApplication;
import '../services/upi_payment_service.dart';

// ─────────────────────────────────────────────────────────────
// Public entry point (remains identical to preserve existing APIs)
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
class _UpiPaymentSheet extends StatefulWidget {
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

  @override
  State<_UpiPaymentSheet> createState() => _UpiPaymentSheetState();
}

class _UpiPaymentSheetState extends State<_UpiPaymentSheet> {
  final UpiPaymentService _paymentService = UpiPaymentService();
  List<UpiAppInfo> _installedApps = [];
  bool _loadingApps = true;

  // Fallback list of predefined apps with manually constructed UpiApplication mapping
  static final List<UpiAppInfo> _kFallbackApps = [
    UpiAppInfo(
      name: 'Google Pay',
      upiApplication: UpiApplication.googlePay,
      bgColor: const Color(0xFF1A73E8),
      label: 'G',
    ),
    UpiAppInfo(
      name: 'PhonePe',
      upiApplication: UpiApplication.phonePe,
      bgColor: const Color(0xFF5F259F),
      label: 'P',
    ),
    UpiAppInfo(
      name: 'Paytm',
      upiApplication: UpiApplication.paytm,
      bgColor: const Color(0xFF002970),
      label: 'T',
    ),
    UpiAppInfo(
      name: 'BHIM',
      upiApplication: UpiApplication.bhim,
      bgColor: const Color(0xFF00897B),
      label: 'B',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadInstalledApps();
  }

  Future<void> _loadInstalledApps() async {
    setState(() => _loadingApps = true);
    try {
      final apps = await _paymentService.getInstalledUpiApps();
      if (mounted) {
        setState(() {
          _installedApps = apps.isNotEmpty ? apps : _kFallbackApps;
          _loadingApps = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _installedApps = _kFallbackApps;
          _loadingApps = false;
        });
      }
    }
  }

  Future<void> _handlePayment(BuildContext context, UpiApplication app) async {
    try {
      // Validate inputs locally first
      UpiPaymentService.validateParameters(
        upiId: widget.upiId,
        receiverName: widget.payeeName,
        amount: widget.amount,
        note: widget.description ?? '',
      );

      final result = await _paymentService.launchUpiPayment(
        app: app,
        upiId: widget.upiId,
        receiverName: widget.payeeName,
        amount: widget.amount,
        note: widget.description ?? '',
      );

      if (context.mounted) {
        String msg = '';
        Color bgColor = Colors.green;
        switch (result.status) {
          case UpiTransactionStatus.SUCCESS:
            msg = 'Payment Successful! ID: ${result.transactionId ?? "N/A"}';
            bgColor = Colors.green;
            break;
          case UpiTransactionStatus.SUBMITTED:
            msg = 'Payment Submitted/Pending. Ref: ${result.approvalRefNo ?? "N/A"}';
            bgColor = Colors.blue;
            break;
          case UpiTransactionStatus.USER_CANCELLED:
            msg = 'Payment cancelled by user.';
            bgColor = Colors.orange;
            break;
          case UpiTransactionStatus.FAILURE:
            msg = 'Payment failed.';
            bgColor = Colors.red;
            break;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: bgColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        String errMsg = 'Payment failed: $e';
        if (e is InvalidUpiIdException) {
          errMsg = e.message;
        } else if (e is InvalidAmountException) {
          errMsg = e.message;
        } else if (e is UpiAppNotInstalledException) {
          errMsg = e.message;
        } else if (e is UpiPaymentCancelledException) {
          errMsg = 'Payment cancelled by user.';
        } else if (e is UpiPaymentFailedException) {
          errMsg = e.message;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  void _showAppChooserDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Select UPI App'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _installedApps.length,
            itemBuilder: (context, index) {
              final app = _installedApps[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: app.bgColor,
                  child: app.iconImage != null
                      ? ClipOval(
                          child: SizedBox(
                            width: 40,
                            height: 40,
                            child: app.iconImage,
                          ),
                        )
                      : Text(app.label, style: const TextStyle(color: Colors.white)),
                ),
                title: Text(app.name),
                onTap: () {
                  Navigator.pop(dialogCtx);
                  if (app.upiApplication != null) {
                    _handlePayment(context, app.upiApplication!);
                  }
                },
              );
            },
          ),
        ),
      ),
    );
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
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Amount header ───────────────────────────────────
          Text(
            '₹${widget.amount.toStringAsFixed(2)}',
            style: GoogleFonts.outfit(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'to ${widget.payeeName}',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 10),

          // ── UPI ID pill with Copy ─────────────────────────────────────
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.upiId));
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
                    widget.upiId,
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
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
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

          // ── App buttons row (dynamic or fallback list) ─────────────
          if (_loadingApps)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: CircularProgressIndicator(),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _installedApps
                    .map((app) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: _AppTile(
                            app: app,
                            onTap: () {
                              if (app.upiApplication != null) {
                                _handlePayment(context, app.upiApplication!);
                              }
                            },
                          ),
                        ))
                    .toList(),
              ),
            ),

          const SizedBox(height: 20),

          // ── Divider ──────────────────────────────────────────
          Row(
            children: [
              Expanded(child: Divider(color: Colors.grey[200])),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ),
              Expanded(child: Divider(color: Colors.grey[200])),
            ],
          ),
          const SizedBox(height: 14),

          // ── Generic button ───────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                if (_installedApps.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('No UPI apps found. Please install one of the supported apps.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else if (_installedApps.length == 1) {
                  final app = _installedApps.first;
                  if (app.upiApplication != null) {
                    _handlePayment(context, app.upiApplication!);
                  }
                } else {
                  _showAppChooserDialog(context);
                }
              },
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Any UPI App'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
// Custom styled App Tile
// ─────────────────────────────────────────────────────────────
class _AppTile extends StatelessWidget {
  final UpiAppInfo app;
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: app.iconImage != null
                  ? SizedBox(
                      width: 64,
                      height: 64,
                      child: app.iconImage,
                    )
                  : Center(
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
