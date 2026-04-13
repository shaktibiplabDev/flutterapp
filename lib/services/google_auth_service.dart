import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GoogleAuthService {
  static const String baseUrl = 'https://rentos.versaero.top/api';
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  static GoogleSignIn? _googleSignIn;
  
  // Initialize with Android client ID (for the app) and Web client ID (for backend verification)
  static void initialize() {
    _googleSignIn = GoogleSignIn(
      scopes: ['email', 'profile'],
      // Android client ID (for the app)
      clientId: '924911513590-6q5f30o660q0pfpog1209aft28qtn7ju.apps.googleusercontent.com',
      // Web client ID (for backend verification - optional but recommended)
      serverClientId: '924911513590-v887ka40ue2t7jnh24fadhk3bqc9mh5i.apps.googleusercontent.com',
    );
  }
  
  static GoogleSignIn get instance {
    _googleSignIn ??= GoogleSignIn(
      scopes: ['email', 'profile'],
      clientId: '924911513590-6q5f30o660q0pfpog1209aft28qtn7ju.apps.googleusercontent.com',
      serverClientId: '924911513590-v887ka40ue2t7jnh24fadhk3bqc9mh5i.apps.googleusercontent.com',
    );
    return _googleSignIn!;
  }
  
  // Native Google Sign-In for Flutter
  static Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // Step 1: Sign in with Google natively
      final GoogleSignInAccount? googleUser = await instance.signIn();
      
      if (googleUser == null) {
        return {'success': false, 'message': 'Sign in cancelled'};
      }
      
      // Step 2: Get authentication details
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;
      
      // Step 3: Get the ID token (THIS IS WHAT BACKEND NEEDS)
      final String? idToken = googleAuth.idToken;
      
      if (idToken == null) {
        return {'success': false, 'message': 'Failed to get ID token'};
      }
      
      debugPrint('Got ID Token successfully');
      debugPrint('ID Token: ${idToken.substring(0, 50)}...');
      
      // Step 4: Send ID token to your backend
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google/signin'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id_token': idToken,
          'device_name': 'Flutter App',
        }),
      );
      
      final data = json.decode(response.body);
      debugPrint('Backend response: $data');
      
      // Step 5: Handle response
      if (data['success'] == true) {
        // Existing user - login successful
        if (data['data'] != null && data['data']['token'] != null) {
          await _storage.write(key: 'user_token', value: data['data']['token']);
          await _storage.write(key: 'user_data', value: json.encode(data['data']['user']));
        }
        return data;
      } 
      else if (data['data'] != null && data['data']['requires_phone'] == true) {
        // New user - needs phone number
        return {
          'success': false,
          'requires_phone': true,
          'id_token': idToken,
          'google_data': data['data']['google_data'],
        };
      }
      
      return data;
      
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      String errorMessage = 'Sign in failed';
      if (e.toString().contains('10')) {
        errorMessage = 'Configuration error. Please check app setup.';
      } else if (e.toString().contains('canceled')) {
        errorMessage = 'Sign in cancelled';
      }
      return {'success': false, 'message': errorMessage};
    }
  }
  
  // Complete registration with phone number
  static Future<Map<String, dynamic>> completeSignUpWithPhone({
    required String idToken,
    required String phone,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/google/signin'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id_token': idToken,
          'phone': phone,
          'device_name': 'Flutter App',
        }),
      );
      
      final data = json.decode(response.body);
      
      if (data['success'] == true && data['data'] != null && data['data']['token'] != null) {
        await _storage.write(key: 'user_token', value: data['data']['token']);
        await _storage.write(key: 'user_data', value: json.encode(data['data']['user']));
      }
      
      return data;
      
    } catch (e) {
      debugPrint('Complete registration error: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }
  
  // Sign out
  static Future<void> signOut() async {
    try {
      await instance.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }
}