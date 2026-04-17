import 'package:flutter/material.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import '../providers/auth_provider.dart';

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  CFPaymentGatewayService? _paymentService;
  bool _isInitialized = false;

  // Store callbacks as instance variables so they're registered once
  Function(String)? _onSuccess;
  Function(String, String)? _onError;
  Function(String)? _onPending;

  // Drive environment from build mode — no manual code change needed for release
  static const _environment = bool.fromEnvironment('dart.vm.product')
      ? CFEnvironment.PRODUCTION
      : CFEnvironment.SANDBOX;

  // Initialize once and register callbacks once
  void initialize() {
    if (_isInitialized) return;

    _paymentService = CFPaymentGatewayService();

    // Register callbacks ONCE here, not inside startPayment
    _paymentService!.setCallback(
      (orderId) => _handlePaymentSuccess(orderId),
      (error, orderId) => _handlePaymentError(error, orderId),
    );

    _isInitialized = true;
    debugPrint('Cashfree Payment Service initialized');
  }

  Future<void> startPayment({
    required String orderId,
    required String paymentSessionId,
    required Function(String orderId) onSuccess,
    required Function(String error, String orderId) onError,
    required Function(String orderId) onPending,
  }) async {
    initialize(); // idempotent — safe to call every time

    // Update stored callbacks for this payment session
    _onSuccess = onSuccess;
    _onError = onError;
    _onPending = onPending;

    try {
      // FIX: Use () instead of .. for build() so the built object is returned,
      // not the builder itself
      final CFSession session = (CFSessionBuilder()
            ..setEnvironment(_environment)
            ..setOrderId(orderId)
            ..setPaymentSessionId(paymentSessionId))
          .build();

      final CFWebCheckoutPayment webCheckoutPayment =
          (CFWebCheckoutPaymentBuilder()..setSession(session)).build();

      _paymentService!.doPayment(webCheckoutPayment);
    } catch (e) {
      debugPrint('Payment initiation error: $e');
      onError(e.toString(), orderId);
    }
  }

  void _handlePaymentSuccess(String orderId) {
    debugPrint('Payment Response — Success. OrderId: $orderId');
    _onSuccess?.call(orderId);
  }

  void _handlePaymentError(CFErrorResponse error, String orderId) {
    final status = (error.getStatus() ?? '').toUpperCase();
    if (status == 'PENDING') {
      debugPrint('Payment Response — Pending. OrderId: $orderId');
      _onPending?.call(orderId);
      return;
    }

    final errorMessage = error.getMessage() ?? 'Payment failed';
    debugPrint('Payment Error: $errorMessage, OrderId: $orderId');
    _onError?.call(errorMessage, orderId);
  }

  Future<bool> verifyPaymentStatus({
    required String orderId,
    required AuthProvider authProvider,
  }) async {
    try {
      final response = await authProvider.checkPaymentStatus(orderId);
      if (response['success'] == true) {
        final status = (response['data']?['status'] ?? '').toString().toUpperCase();
        return status == 'SUCCESS' || status == 'COMPLETED';
      }
      return false;
    } catch (e) {
      debugPrint('Payment verification error: $e');
      return false;
    }
  }
}
