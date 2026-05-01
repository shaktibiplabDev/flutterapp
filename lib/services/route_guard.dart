// Create lib/services/route_guard.dart
import 'package:flutter/material.dart';

class RouteGuard extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _checkAuth(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      _checkAuth(newRoute);
    }
  }

  void _checkAuth(Route<dynamic> route) {
    final settings = route.settings;
    final isAuthRoute = settings.name == '/login' ||
        settings.name == '/register' ||
        settings.name == '/splash' ||
        settings.name == '/forgot-password' ||
        settings.name == '/reset-password' ||
        settings.name == '/verify-email' ||
        settings.name == '/google-phone' ||
        settings.name == '/setup-password' ||
        settings.name == '/email-verification-required';
    
    if (!isAuthRoute) {
      // Check if user is authenticated
      // This requires access to AuthProvider - implement accordingly
    }
  }
}