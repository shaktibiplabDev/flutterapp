import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/google_auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  User? _user;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Google Sign-In state
  String? _pendingGoogleIdToken;
  Map<String, dynamic>? _pendingGoogleData;
  bool _needsPhoneForGoogle = false;

  // Password reset state
  String? _passwordResetToken;
  String? _passwordResetEmail;

  // Getters
  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _token != null && _user != null;
  
  // Google getters
  String? get pendingGoogleIdToken => _pendingGoogleIdToken;
  Map<String, dynamic>? get pendingGoogleData => _pendingGoogleData;
  bool get needsPhoneForGoogle => _needsPhoneForGoogle;
  
  // Password reset getters
  String? get passwordResetToken => _passwordResetToken;
  String? get passwordResetEmail => _passwordResetEmail;

  // ==================== REGISTRATION & LOGIN ====================

  // Register
  Future<bool> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.register(
        name: name,
        phone: phone,
        email: email,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );

      if (response['success'] == true) {
        _setLoading(false);
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Registration failed';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
      _setLoading(false);
      return false;
    }
  }

  // Login
  Future<bool> login({
    required String login,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.login(
        login: login,
        password: password,
      );

      if (response['success'] == true && response['data']?['token'] != null) {
        _token = response['data']['token'];
        if (response['data']['user'] != null) {
          _user = User.fromJson(response['data']['user']);
        }
        _setLoading(false);
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Login failed';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
      _setLoading(false);
      return false;
    }
  }

  // ==================== EMAIL VERIFICATION ====================

  // Send email verification OTP
  Future<bool> sendEmailVerificationOTP({
    required String email,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.sendEmailVerificationOTP(email: email);
      _setLoading(false);
      return response['success'] == true;
    } catch (e) {
      _errorMessage = 'Failed to send verification OTP: $e';
      _setLoading(false);
      return false;
    }
  }

  // Verify email with OTP
  Future<bool> verifyEmailOTP({
    required String email,
    required String otp,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.verifyEmailOTP(email: email, otp: otp);

      if (response['success'] == true) {
        await refreshUser();
        _setLoading(false);
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Email verification failed';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'Verification error: $e';
      _setLoading(false);
      return false;
    }
  }

  // Resend email verification OTP
  Future<bool> resendEmailVerificationOTP({
    required String email,
  }) async {
    try {
      final response = await _apiService.resendEmailVerificationOTP(email: email);
      return response['success'] == true;
    } catch (e) {
      return false;
    }
  }

  // ==================== PASSWORD RESET ====================

  // Send password reset OTP
  Future<bool> sendPasswordResetOTP({
    required String email,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.sendPasswordResetOTP(email: email);

      if (response['success'] == true) {
        _passwordResetToken = response['data']?['token'];
        _passwordResetEmail = response['data']?['email'];
        _setLoading(false);
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to send OTP';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'Failed to send OTP: $e';
      _setLoading(false);
      return false;
    }
  }

  // Reset password with OTP
  Future<bool> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String passwordConfirmation,
  }) async {
    if (_passwordResetToken == null) {
      _errorMessage = 'No password reset token found';
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.resetPassword(
        email: email,
        token: _passwordResetToken!,
        otp: otp,
        password: password,
        passwordConfirmation: passwordConfirmation,
      );

      if (response['success'] == true) {
        _passwordResetToken = null;
        _passwordResetEmail = null;
        _setLoading(false);
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Password reset failed';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'Reset error: $e';
      _setLoading(false);
      return false;
    }
  }

  // Resend password reset OTP
  Future<bool> resendPasswordResetOTP({
    required String email,
  }) async {
    try {
      final response = await _apiService.resendPasswordResetOTP(email: email);

      if (response['success'] == true) {
        _passwordResetToken = response['data']?['token'];
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Clear password reset data
  void clearPasswordResetData() {
    _passwordResetToken = null;
    _passwordResetEmail = null;
    notifyListeners();
  }

  // ==================== GOOGLE AUTH (NATIVE) ====================

  // Google Sign-In (Native)
  Future<bool> signInWithGoogle(BuildContext context) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await GoogleAuthService.signInWithGoogle();

      if (result['success'] == true) {
        // Existing user - login successful
        _token = result['data']['token'];
        if (result['data']['user'] != null) {
          _user = User.fromJson(result['data']['user']);
        }
        _needsPhoneForGoogle = false;
        _pendingGoogleIdToken = null;
        _pendingGoogleData = null;
        _setLoading(false);
        return true;
      } 
      else if (result['requires_phone'] == true) {
        // New user - needs phone number
        _pendingGoogleIdToken = result['id_token'];
        _pendingGoogleData = result['google_data'];
        _needsPhoneForGoogle = true;
        _setLoading(false);
        return true;
      }
      
      _errorMessage = result['message'] ?? 'Google sign in failed';
      _setLoading(false);
      return false;
      
    } catch (e) {
      _errorMessage = 'Google sign in error: $e';
      _setLoading(false);
      return false;
    }
  }

  // Complete Google Registration with Phone
  Future<bool> completeGoogleRegistrationWithPhone({
    required String phone,
  }) async {
    if (_pendingGoogleIdToken == null) {
      _errorMessage = 'No pending Google registration';
      return false;
    }

    _setLoading(true);

    try {
      final result = await GoogleAuthService.completeSignUpWithPhone(
        idToken: _pendingGoogleIdToken!,
        phone: phone,
      );

      if (result['success'] == true) {
        _token = result['data']['token'];
        if (result['data']['user'] != null) {
          _user = User.fromJson(result['data']['user']);
        }

        _pendingGoogleIdToken = null;
        _pendingGoogleData = null;
        _needsPhoneForGoogle = false;
        _setLoading(false);
        return true;
      } else {
        _errorMessage = result['message'] ?? 'Registration failed';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'Registration error: $e';
      _setLoading(false);
      return false;
    }
  }

  // Setup password for Google user
  Future<bool> setupPassword({
    required String password,
    required String passwordConfirmation,
  }) async {
    _setLoading(true);

    try {
      final response = await _apiService.setupPassword(
        password: password,
        passwordConfirmation: passwordConfirmation,
      );

      if (response['success'] == true && response['data']?['user'] != null) {
        _user = User.fromJson(response['data']['user']);
        _setLoading(false);
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Password setup failed';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'Password setup error: $e';
      _setLoading(false);
      return false;
    }
  }

  // ==================== UTILITIES ====================

  // Refresh user data
  Future<void> refreshUser() async {
    try {
      final response = await _apiService.getCurrentUser();
      if (response['data']?['user'] != null) {
        _user = User.fromJson(response['data']['user']);
        notifyListeners();
      }
    } catch (e) {
      print('Refresh user error: $e');
    }
  }

  // Logout
  Future<void> logout() async {
    _setLoading(true);
    try {
      await _apiService.logout();
      await GoogleAuthService.signOut();
      _user = null;
      _token = null;
      _pendingGoogleIdToken = null;
      _pendingGoogleData = null;
      _needsPhoneForGoogle = false;
      _passwordResetToken = null;
      _passwordResetEmail = null;
    } catch (e) {
      print('Logout error: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}