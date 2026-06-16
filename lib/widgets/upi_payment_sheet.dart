import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_upi_india/flutter_upi_india.dart' show UpiApplication;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
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
  final String upiId;
  final String payeeName;
  final double amount;
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
  int _selectedTabIndex = 0; // 0: Direct, 1: QR, 2: Manual
  final GlobalKey _qrKey = GlobalKey();
  bool _sharingQr = false;

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

  Future<void> _handleDirectLaunch(UpiApplication app) async {
    // Copy the UPI ID to clipboard first
    await Clipboard.setData(ClipboardData(text: widget.upiId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('UPI ID Copied! Opening ${app.appName}...'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    final success = await _paymentService.launchUpiAppDirectly(app);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to launch ${app.appName} automatically. Please open it manually and paste the UPI ID.'),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _shareQrCode() async {
    setState(() => _sharingQr = true);
    try {
      final String upiUri = 'upi://pay'
          '?pa=${widget.upiId}'
          '&pn=${Uri.encodeComponent(widget.payeeName)}'
          '&am=${widget.amount.toStringAsFixed(2)}'
          '&cu=INR'
          '${widget.description != null && widget.description!.trim().isNotEmpty ? '&tn=${Uri.encodeComponent("Payment for ${widget.description!.trim()}")}' : ''}';

      final qrPainter = QrPainter(
        data: upiUri,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0xFF1B1B1B),
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF1B1B1B),
        ),
        gapless: true,
      );

      final ByteData? byteData = await qrPainter.toImageData(400);
      if (byteData == null) {
        throw Exception("Failed to generate QR image data.");
      }
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/upi_payment_qr.png').create();
      await file.writeAsBytes(pngBytes);

      final String message = '💸 Split Expenses Payment Request\n'
          '---------------------------------\n'
          'Payee: ${widget.payeeName}\n'
          'Amount: ₹${widget.amount.toStringAsFixed(2)}\n'
          'UPI ID: ${widget.upiId}\n\n'
          'Direct Payment Link:\n'
          '$upiUri';

      await Share.shareXFiles(
        [XFile(file.path)],
        text: message,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share QR Code: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sharingQr = false);
      }
    }
  }

  Widget _buildTabHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTabButton(0, 'Direct Pay', Icons.flash_on_rounded),
          _buildTabButton(1, 'Scan QR', Icons.qr_code_2_rounded),
          _buildTabButton(2, 'Manual Pay', Icons.edit_note_rounded),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = _selectedTabIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.grey[800] : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDirectPayTab() {
    return Column(
      children: [
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'PAY WITH INSTANT REDIRECT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Colors.grey[500],
            ),
          ),
        ),
        const SizedBox(height: 12),
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
              children: [
                ..._installedApps.map((app) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: _AppTile(
                        app: app,
                        onTap: () {
                          if (app.upiApplication != null) {
                            _handlePayment(context, app.upiApplication!);
                          }
                        },
                      ),
                    )),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Container(
                    width: 1.2,
                    height: 50,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[300],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: _ShareTile(
                    label: 'Share QR',
                    icon: Icons.share_rounded,
                    bgColor: Theme.of(context).colorScheme.primary,
                    isLoading: _sharingQr,
                    onTap: _shareQrCode,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: _ShareTile(
                    label: 'WhatsApp',
                    icon: Icons.chat_bubble_outline_rounded,
                    bgColor: const Color(0xFF25D366),
                    isLoading: _sharingQr,
                    onTap: _shareQrCode,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withOpacity(0.15)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Note: If Google Pay/PhonePe shows "daily limit spent" or other errors, it is because UPI deep links for P2P transfers are restricted by banks/NPCI. Use the QR Code or Manual Pay tabs above.',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.red[200]
                        : Colors.red[850],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQrCodeTab() {
    final String upiUri = 'upi://pay'
        '?pa=${widget.upiId}'
        '&pn=${Uri.encodeComponent(widget.payeeName)}'
        '&am=${widget.amount.toStringAsFixed(2)}'
        '&cu=INR'
        '${widget.description != null && widget.description!.trim().isNotEmpty ? '&tn=${Uri.encodeComponent("Payment for ${widget.description!.trim()}")}' : ''}';

    return Column(
      children: [
        const SizedBox(height: 16),
        RepaintBoundary(
          key: _qrKey,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: QrImageView(
              data: upiUri,
              version: QrVersions.auto,
              size: 180.0,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF1B1B1B),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF1B1B1B),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _sharingQr ? null : _shareQrCode,
                icon: _sharingQr
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.share_rounded, size: 16),
                label: Text(_sharingQr ? 'Preparing...' : 'Share QR Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _sharingQr ? null : _shareQrCode,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: const Text('Send WhatsApp'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF25D366), // WhatsApp Green
                  side: const BorderSide(color: Color(0xFF25D366)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.camera_alt_outlined, 
                    color: Theme.of(context).colorScheme.primary, 
                    size: 16
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'How to pay using QR Code:',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildStepRow('1', 'Take a screenshot of this QR Code, or tap "Share QR Code" / "Send WhatsApp" above.'),
              _buildStepRow('2', 'Open Google Pay, PhonePe, or Paytm.'),
              _buildStepRow('3', 'Tap the Scan icon and select Gallery/Upload Photo.'),
              _buildStepRow('4', 'Select the screenshot or saved QR to pay ₹${widget.amount.toStringAsFixed(2)} directly.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepRow(String number, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(top: 2, right: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: isDark ? Colors.grey[300] : Colors.grey[750],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualPayTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UPI ID',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.upiId,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.upiId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('UPI ID copied to clipboard'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('Copy'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'TAP APP TO LAUNCH & PASTE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Colors.grey[500],
            ),
          ),
        ),
        const SizedBox(height: 12),
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
              children: _installedApps
                  .map((app) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: _AppTile(
                          app: app,
                          onTap: () {
                            if (app.upiApplication != null) {
                              _handleDirectLaunch(app.upiApplication!);
                            }
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Quick steps: The UPI ID is copied automatically when you tap any app above. Go to "Pay UPI ID" in the opened app, paste the ID, and enter ₹${widget.amount.toStringAsFixed(2)}.',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: isDark ? Colors.orange[200] : Colors.orange[850],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
      child: Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag Handle ────────────────────────────────────
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
        
            // ── Amount & Payee Name ────────────────────────────
            Text(
              '₹${widget.amount.toStringAsFixed(2)}',
              style: GoogleFonts.outfit(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'to ${widget.payeeName}',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[400]
                    : Colors.grey[600],
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 20),
        
            // ── Segmented Tab Header ───────────────────────────
            _buildTabHeader(),
            const SizedBox(height: 12),
        
            // ── Tab Body Content ───────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: KeyedSubtree(
                key: ValueKey<int>(_selectedTabIndex),
                child: _selectedTabIndex == 0
                    ? _buildDirectPayTab()
                    : _selectedTabIndex == 1
                        ? _buildQrCodeTab()
                        : _buildManualPayTab(),
              ),
            ),
        
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 12),
        
            // ── Cancel/Close button ────────────────────────────
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ),
          ],
        ),
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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: app.bgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: app.bgColor.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: app.iconImage != null
                  ? SizedBox(
                      width: 60,
                      height: 60,
                      child: app.iconImage,
                    )
                  : Center(
                      child: Text(
                        app.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
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
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[300]
                  : Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ShareTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bgColor;
  final VoidCallback onTap;
  final bool isLoading;

  const _ShareTile({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: bgColor.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      icon,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[300]
                  : Colors.grey[700],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
