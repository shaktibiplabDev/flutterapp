import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'dart:async';

/// A base widget that monitors authentication state and redirects to login when unauthorized
abstract class AuthAwareWidget extends StatefulWidget {
  const AuthAwareWidget({super.key});
}

abstract class AuthAwareWidgetState<T extends AuthAwareWidget> extends State<T> {
  bool _isRedirecting = false;
  StreamSubscription? _unauthorizedSubscription;

  @override
  void initState() {
    super.initState();
    // Listen to unauthorized events after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupAuthListener();
    });
  }
  
  void _setupAuthListener() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _unauthorizedSubscription = authProvider.onUnauthorized.listen((_) {
      if (!_isRedirecting && mounted) {
        _redirectToLogin();
      }
    });
  }
  
  void _redirectToLogin() {
    if (_isRedirecting) return;
    _isRedirecting = true;
    
    // Show session expired message
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text('Session expired. Please login again.')),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
    
    // Navigate to login after delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    });
  }

  @override
  void dispose() {
    _unauthorizedSubscription?.cancel();
    super.dispose();
  }
}