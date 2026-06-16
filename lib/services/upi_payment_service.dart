// ignore_for_file: constant_identifier_names

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_upi_india/flutter_upi_india.dart' as f_upi;
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────
// CUSTOM UPI EXCEPTIONS (Retained for backward compatibility)
// ─────────────────────────────────────────────────────────────

class InvalidUpiIdException implements Exception {
  final String message;
  InvalidUpiIdException(this.message);
  @override
  String toString() => 'InvalidUpiIdException: $message';
}

class InvalidAmountException implements Exception {
  final String message;
  InvalidAmountException(this.message);
  @override
  String toString() => 'InvalidAmountException: $message';
}

class UpiAppNotInstalledException implements Exception {
  final String message;
  UpiAppNotInstalledException(this.message);
  @override
  String toString() => 'UpiAppNotInstalledException: $message';
}

class UpiPaymentCancelledException implements Exception {
  final String message;
  UpiPaymentCancelledException(this.message);
  @override
  String toString() => 'UpiPaymentCancelledException: $message';
}

class UpiPaymentFailedException implements Exception {
  final String message;
  UpiPaymentFailedException(this.message);
  @override
  String toString() => 'UpiPaymentFailedException: $message';
}

// ─────────────────────────────────────────────────────────────
// MODEL CLASSES
// ─────────────────────────────────────────────────────────────

class UpiAppInfo {
  final String name;
  final f_upi.UpiApplication? upiApplication;
  final Color bgColor;
  final String label;
  final Widget? iconImage; // Renders the actual high-quality logo

  const UpiAppInfo({
    required this.name,
    this.upiApplication,
    required this.bgColor,
    required this.label,
    this.iconImage,
  });
}

enum UpiTransactionStatus {
  SUCCESS,
  FAILURE,
  SUBMITTED,
  USER_CANCELLED,
}

class UpiTransactionResult {
  final String? transactionId;
  final String? responseCode;
  final String? approvalRefNo;
  final UpiTransactionStatus status;
  final String? rawResponse;

  UpiTransactionResult({
    this.transactionId,
    this.responseCode,
    this.approvalRefNo,
    required this.status,
    this.rawResponse,
  });
}

// ─────────────────────────────────────────────────────────────
// REUSABLE UPI PAYMENT SERVICE
// ─────────────────────────────────────────────────────────────

class UpiPaymentService {
  static const String _tag = 'UpiPaymentService';

  // Strict validation regex for UPI Virtual Payment Address (VPA)
  static final RegExp _upiIdRegex = RegExp(
    r'^[a-zA-Z0-9.\-_]+@[a-zA-Z0-9.\-_]+$',
  );

  /// Validates the payment parameters to prevent malformed queries or limits issues.
  static void validateParameters({
    required String upiId,
    required String receiverName,
    required double amount,
    required String note,
  }) {
    // 1. UPI VPA validation
    final trimmedUpi = upiId.trim();
    if (trimmedUpi.isEmpty) {
      throw InvalidUpiIdException('UPI ID cannot be empty.');
    }
    if (!_upiIdRegex.hasMatch(trimmedUpi)) {
      throw InvalidUpiIdException(
        'Malformed UPI ID "$upiId". Expected format is receiver@bank.',
      );
    }

    // 2. Receiver Name validation
    if (receiverName.trim().isEmpty) {
      throw InvalidUpiIdException('Receiver Name cannot be empty.');
    }

    // 3. Amount validation (UPI limit is ₹1,00,000 per transaction)
    if (amount <= 0.0) {
      throw InvalidAmountException('Payment amount must be greater than zero.');
    }
    if (amount > 100000.0) {
      throw InvalidAmountException(
        'Transaction limit exceeded. UPI limit is ₹1,00,000 per transaction.',
      );
    }

    // 4. Note validation
    if (note.length > 80) {
      throw InvalidAmountException('Transaction note must not exceed 80 characters.');
    }
  }

  /// Launch UPI transaction using the flutter_upi_india package.
  Future<UpiTransactionResult> launchUpiPayment({
    required f_upi.UpiApplication app,
    required String upiId,
    required String receiverName,
    required double amount,
    String note = '',
  }) async {
    developer.log(
      'Initiating payment with flutter_upi_india: app=${app.appName}, package=${app.androidPackageName}, upiId=$upiId, receiver=$receiverName, amount=$amount, note=$note',
      name: _tag,
    );

    // Perform safety checks and parameter validation
    validateParameters(
      upiId: upiId,
      receiverName: receiverName,
      amount: amount,
      note: note,
    );

    try {
      final String transactionRef = 'TXN${DateTime.now().millisecondsSinceEpoch}';

      final f_upi.UpiTransactionResponse response = await f_upi.UpiPay.initiateTransaction(
        app: app,
        receiverUpiAddress: upiId.trim(),
        receiverName: receiverName.trim(),
        transactionRef: transactionRef,
        amount: amount.toStringAsFixed(2), // Max 2 decimal places as required by UPI spec
        transactionNote: note.trim().isNotEmpty ? note.trim() : 'Split Expenses Payment',
      );

      developer.log(
        'UPI Response: status=${response.status}, txnId=${response.txnId}, code=${response.responseCode}, ref=${response.approvalRefNo}',
        name: _tag,
      );

      UpiTransactionStatus status;
      if (response.status == f_upi.UpiTransactionStatus.success) {
        status = UpiTransactionStatus.SUCCESS;
      } else if (response.status == f_upi.UpiTransactionStatus.submitted) {
        status = UpiTransactionStatus.SUBMITTED;
      } else {
        status = UpiTransactionStatus.FAILURE;
      }

      return UpiTransactionResult(
        transactionId: response.txnId,
        responseCode: response.responseCode,
        approvalRefNo: response.approvalRefNo,
        status: status,
        rawResponse: response.rawResponse ?? response.toString(),
      );
    } catch (e) {
      developer.log('Payment transaction threw an exception: $e', name: _tag);
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('user_canceled') || errStr.contains('canceled') || errStr.contains('cancel')) {
        return UpiTransactionResult(
          status: UpiTransactionStatus.USER_CANCELLED,
          rawResponse: e.toString(),
        );
      } else if (errStr.contains('app_not_installed') || errStr.contains('not installed')) {
        throw UpiAppNotInstalledException('Selected UPI app is not installed.');
      } else {
        throw UpiPaymentFailedException('Payment failed: $e');
      }
    }
  }

  /// Detects all installed UPI apps and maps them to UpiAppInfo for the UI.
  Future<List<UpiAppInfo>> getInstalledUpiApps() async {
    try {
      final List<f_upi.ApplicationMeta> apps = await f_upi.UpiPay.getInstalledUpiApplications(
        statusType: f_upi.UpiApplicationDiscoveryAppStatusType.all,
      );

      developer.log('Detected ${apps.length} UPI apps.', name: _tag);

      final List<UpiAppInfo> mappedApps = [];
      for (final app in apps) {
        final name = _getAppDisplayName(app.upiApplication);
        mappedApps.add(UpiAppInfo(
          name: name,
          upiApplication: app.upiApplication,
          bgColor: _getAppBgColor(app.upiApplication),
          label: _getAppLabel(name),
          iconImage: app.iconImage(48),
        ));
      }
      return mappedApps;
    } catch (e) {
      developer.log('Failed to detect installed UPI apps: $e', name: _tag);
      return [];
    }
  }

  static String _getAppDisplayName(f_upi.UpiApplication app) {
    if (app == f_upi.UpiApplication.googlePay) return 'Google Pay';
    if (app == f_upi.UpiApplication.phonePe) return 'PhonePe';
    if (app == f_upi.UpiApplication.paytm) return 'Paytm';
    if (app == f_upi.UpiApplication.bhim) return 'BHIM';
    if (app == f_upi.UpiApplication.amazonPay) return 'Amazon Pay';
    if (app == f_upi.UpiApplication.mobikwik) return 'Mobikwik';
    return app.appName;
  }

  static Color _getAppBgColor(f_upi.UpiApplication app) {
    if (app == f_upi.UpiApplication.googlePay) return const Color(0xFF1A73E8); // Blue
    if (app == f_upi.UpiApplication.phonePe) return const Color(0xFF5F259F);    // Purple
    if (app == f_upi.UpiApplication.paytm) return const Color(0xFF002970);      // Deep Blue
    if (app == f_upi.UpiApplication.bhim) return const Color(0xFF00897B);       // Teal
    return const Color(0xFF0F9D58); // Generic/other apps
  }

  static String _getAppLabel(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('google')) return 'G';
    if (lowerName.contains('phonepe')) return 'P';
    if (lowerName.contains('paytm')) return 'T';
    if (lowerName.contains('bhim')) return 'B';
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  /// Launches a UPI App directly to its home screen.
  /// Returns true if launched successfully.
  Future<bool> launchUpiAppDirectly(f_upi.UpiApplication app) async {
    String scheme = '';
    if (app == f_upi.UpiApplication.googlePay) {
      scheme = 'gpay';
    } else if (app == f_upi.UpiApplication.phonePe) {
      scheme = 'phonepe';
    } else if (app == f_upi.UpiApplication.paytm) {
      scheme = 'paytmmp';
    } else if (app == f_upi.UpiApplication.bhim) {
      scheme = 'bhim';
    } else if (app == f_upi.UpiApplication.amazonPay) {
      scheme = 'amazonpay';
    }

    if (scheme.isNotEmpty) {
      try {
        final Uri url = Uri.parse('$scheme://');
        if (await canLaunchUrl(url)) {
          final success = await launchUrl(url, mode: LaunchMode.externalApplication);
          developer.log('Direct launch of $scheme:// success=$success', name: _tag);
          return success;
        } else {
          developer.log('canLaunchUrl returned false for $scheme://', name: _tag);
        }
      } catch (e) {
        developer.log('Error direct launching app $scheme: $e', name: _tag);
      }
    }

    // Fallback: Try launching using common standard intent or general upi:// scheme
    try {
      final Uri genericUpi = Uri.parse('upi://');
      if (await canLaunchUrl(genericUpi)) {
        final success = await launchUrl(genericUpi, mode: LaunchMode.externalApplication);
        return success;
      }
    } catch (e) {
      developer.log('Error launching generic upi://: $e', name: _tag);
    }

    return false;
  }
}
