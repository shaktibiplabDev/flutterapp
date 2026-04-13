import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'https://rentos.versaero.top/api'; // Update with your API URL
  
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  // Headers
  Future<Map<String, String>> getHeaders() async {
    final token = await _storage.read(key: 'user_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
  
  // Register User
  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'name': name,
        'phone': phone,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      }),
    );
    
    return json.decode(response.body);
  }
  
  // Login with email or phone
  Future<Map<String, dynamic>> login({
    required String login,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'login': login,
        'password': password,
      }),
    );
    
    final data = json.decode(response.body);
    
    if (response.statusCode == 200 && data['data']?['token'] != null) {
      await _storage.write(key: 'user_token', value: data['data']['token']);
      await _storage.write(key: 'user_data', value: json.encode(data['data']['user']));
    }
    
    return data;
  }
  
  // Get current user
  Future<Map<String, dynamic>> getCurrentUser() async {
    final headers = await getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/auth/me'),
      headers: headers,
    );
    
    return json.decode(response.body);
  }
  
  // Change password
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final headers = await getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/change-password'),
      headers: headers,
      body: json.encode({
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      }),
    );
    
    return json.decode(response.body);
  }
  
  // Refresh token
  Future<Map<String, dynamic>> refreshToken() async {
    final headers = await getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/refresh-token'),
      headers: headers,
    );
    
    final data = json.decode(response.body);
    
    if (data['data']?['token'] != null) {
      await _storage.write(key: 'user_token', value: data['data']['token']);
    }
    
    return data;
  }
  
  // Logout
  Future<Map<String, dynamic>> logout() async {
    final headers = await getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/logout'),
      headers: headers,
    );
    
    await _storage.delete(key: 'user_token');
    await _storage.delete(key: 'user_data');
    
    return json.decode(response.body);
  }
  
  // ==================== EMAIL VERIFICATION ====================
  
  // Send email verification OTP
  Future<Map<String, dynamic>> sendEmailVerificationOTP({
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/email/verify/send'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email}),
    );
    
    return json.decode(response.body);
  }
  
  // Verify email with OTP
  Future<Map<String, dynamic>> verifyEmailOTP({
    required String email,
    required String otp,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/email/verify/otp'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'otp': otp,
      }),
    );
    
    final data = json.decode(response.body);
    
    // If verification successful, update stored user data
    if (response.statusCode == 200 && data['success'] == true) {
      final headers = await getHeaders();
      final userResponse = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: headers,
      );
      final userData = json.decode(userResponse.body);
      if (userData['data']?['user'] != null) {
        await _storage.write(key: 'user_data', value: json.encode(userData['data']['user']));
      }
    }
    
    return data;
  }
  
  // Resend email verification OTP
  Future<Map<String, dynamic>> resendEmailVerificationOTP({
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/email/verify/resend'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email}),
    );
    
    return json.decode(response.body);
  }
  
  // ==================== PASSWORD RESET ====================
  
  // Send password reset OTP
  Future<Map<String, dynamic>> sendPasswordResetOTP({
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/password/forgot'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email}),
    );
    
    return json.decode(response.body);
  }
  
  // Reset password with OTP
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String token,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/password/reset'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'token': token,
        'otp': otp,
        'password': password,
        'password_confirmation': passwordConfirmation,
      }),
    );
    
    return json.decode(response.body);
  }
  
  // Resend password reset OTP
  Future<Map<String, dynamic>> resendPasswordResetOTP({
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/password/resend-otp'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email}),
    );
    
    return json.decode(response.body);
  }
  
  // ==================== GOOGLE AUTH ====================
  
  // Google Native Login (Mobile)
  Future<Map<String, dynamic>> googleNativeLogin({
    required String email,
    required String name,
    required String googleId,
    String? avatar,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/google/native-login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'name': name,
        'google_id': googleId,
        'avatar': avatar,
        'device_name': 'Mobile App',
      }),
    );
    
    final data = json.decode(response.body);
    
    if (response.statusCode == 200 && data['data']?['token'] != null) {
      await _storage.write(key: 'user_token', value: data['data']['token']);
      await _storage.write(key: 'user_data', value: json.encode(data['data']['user']));
    }
    
    return data;
  }
  
  // Complete Google Registration with Phone
  Future<Map<String, dynamic>> completeGoogleRegistration({
    required String tempToken,
    required String phone,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/google/complete-registration'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'temp_token': tempToken,
        'phone': phone,
        'device_name': 'Mobile App',
      }),
    );
    
    final data = json.decode(response.body);
    
    if (response.statusCode == 200 && data['data']?['token'] != null) {
      await _storage.write(key: 'user_token', value: data['data']['token']);
      await _storage.write(key: 'user_data', value: json.encode(data['data']['user']));
    }
    
    return data;
  }
  
  // Setup password for Google user
  Future<Map<String, dynamic>> setupPassword({
    required String password,
    required String passwordConfirmation,
  }) async {
    final headers = await getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/google/set-password'),
      headers: headers,
      body: json.encode({
        'password': password,
        'password_confirmation': passwordConfirmation,
      }),
    );
    
    final data = json.decode(response.body);
    
    if (response.statusCode == 200 && data['data']?['user'] != null) {
      await _storage.write(key: 'user_data', value: json.encode(data['data']['user']));
    }
    
    return data;
  }
}