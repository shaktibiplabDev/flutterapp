import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiInterceptor {
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  static Future<bool> isTokenValid() async {
    final token = await _storage.read(key: 'user_token');
    if (token == null || token.isEmpty) {
      return false;
    }
    
    // Optional: Check token expiration if you store expiry
    final expiryStr = await _storage.read(key: 'token_expiry');
    if (expiryStr != null) {
      try {
        final expiry = DateTime.parse(expiryStr);
        if (DateTime.now().isAfter(expiry)) {
          return false;
        }
      } catch (e) {
        // Ignore parsing errors
      }
    }
    
    return true;
  }
  
  static Future<void> handleUnauthorized(BuildContext context) async {
    // Clear stored auth data
    await _storage.delete(key: 'user_token');
    await _storage.delete(key: 'user_data');
    await _storage.delete(key: 'token_expiry');
    
    // Show session expired message
    if (context.mounted) {
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
          duration: Duration(seconds: 3),
        ),
      );
      
      // Navigate to login after a short delay
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (context.mounted) {
        // Clear all routes and go to login
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    }
  }
  
  static Future<http.Response> getWithAuth(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final token = await _storage.read(key: 'user_token');
    final defaultHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };
    
    final response = await http.get(url, headers: defaultHeaders);
    
    // Check for unauthorized
    if (response.statusCode == 401) {
      _handleGlobalUnauthorized();
    }
    
    return response;
  }
  
  static Future<http.Response> postWithAuth(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final token = await _storage.read(key: 'user_token');
    final defaultHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };
    
    final response = await http.post(url, headers: defaultHeaders, body: body);
    
    // Check for unauthorized
    if (response.statusCode == 401) {
      _handleGlobalUnauthorized();
    }
    
    return response;
  }
  
  static Future<http.Response> putWithAuth(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final token = await _storage.read(key: 'user_token');
    final defaultHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };
    
    final response = await http.put(url, headers: defaultHeaders, body: body);
    
    // Check for unauthorized
    if (response.statusCode == 401) {
      _handleGlobalUnauthorized();
    }
    
    return response;
  }
  
  static Future<http.Response> deleteWithAuth(
    Uri url, {
    Map<String, String>? headers,
  }) async {
    final token = await _storage.read(key: 'user_token');
    final defaultHeaders = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };
    
    final response = await http.delete(url, headers: defaultHeaders);
    
    // Check for unauthorized
    if (response.statusCode == 401) {
      _handleGlobalUnauthorized();
    }
    
    return response;
  }
  
  static void _handleGlobalUnauthorized() async {
    // Clear storage
    await _storage.delete(key: 'user_token');
    await _storage.delete(key: 'user_data');
    await _storage.delete(key: 'token_expiry');
    
    // Navigate to login if we have a navigator key
    if (navigatorKey.currentContext != null) {
      // Show message
      if (navigatorKey.currentContext!.mounted) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).clearSnackBars();
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
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
          ),
        );
      }
      
      // Navigate to login
      await Future.delayed(const Duration(milliseconds: 500));
      if (navigatorKey.currentContext != null && navigatorKey.currentContext!.mounted) {
        Navigator.of(navigatorKey.currentContext!).pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      }
    }
  }
}