import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/google_auth_service.dart';
import '../services/api_interceptor.dart';

class _CacheEntry<T> {
  final T data;
  final DateTime expiresAt;

  _CacheEntry({required this.data, required this.expiresAt});

  bool get isValid => DateTime.now().isBefore(expiresAt);
}

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

  // App-level response cache (in-memory)
  final Map<String, _CacheEntry<Map<String, dynamic>>> _responseCache = {};
  final Map<String, Future<Map<String, dynamic>>> _inFlightRequests = {};

  final StreamController<void> _unauthorizedController =
      StreamController<void>.broadcast();
  Stream<void> get onUnauthorized => _unauthorizedController.stream;
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

  Future<Map<String, dynamic>> _cachedMapRequest({
    required String key,
    required Duration ttl,
    required Future<Map<String, dynamic>> Function() request,
    bool forceRefresh = false,
    bool cacheOnlySuccess = true,
  }) async {
    if (!forceRefresh) {
      final entry = _responseCache[key];
      if (entry != null && entry.isValid) {
        return entry.data;
      }

      final inFlight = _inFlightRequests[key];
      if (inFlight != null) {
        return inFlight;
      }
    }

    final future = request();
    _inFlightRequests[key] = future;

    try {
      final result = await future;

      // Check for unauthorized response
      if (result['unauthorized'] == true ||
          result['message']?.toString().contains('Session expired') == true ||
          result['message']?.toString().contains('Unauthenticated') == true) {
        await handleUnauthorized();
        return result;
      }

      final shouldCache = !cacheOnlySuccess || result['success'] == true;
      if (shouldCache) {
        _responseCache[key] = _CacheEntry<Map<String, dynamic>>(
          data: result,
          expiresAt: DateTime.now().add(ttl),
        );
      }
      return result;
    } finally {
      if (identical(_inFlightRequests[key], future)) {
        _inFlightRequests.remove(key);
      }
    }
  }

  void _invalidateCacheByPrefix(String prefix) {
    final keys =
        _responseCache.keys.where((key) => key.startsWith(prefix)).toList();
    for (final key in keys) {
      _responseCache.remove(key);
    }
  }

  void _invalidateWalletCache() {
    _invalidateCacheByPrefix('wallet:');
  }

  void _invalidateVehicleCache() {
    _invalidateCacheByPrefix('vehicles:');
    _invalidateCacheByPrefix('availableVehicles:');
  }

  void _invalidateRentalCache() {
    _invalidateCacheByPrefix('rentals:');
    _invalidateCacheByPrefix('rentalStats:');
    _invalidateCacheByPrefix('rentalDetails:');
    _invalidateCacheByPrefix('rentalPhase:');
  }

  void _invalidateBusinessCache() {
    _invalidateCacheByPrefix('business:');
    _invalidateCacheByPrefix('gst:');
  }

  void _invalidateCustomersCache() {
    _invalidateCacheByPrefix('customers:');
  }

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
      final response =
          await _apiService.resendEmailVerificationOTP(email: email);
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
      } else if (result['requires_phone'] == true) {
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

  // ==================== VEHICLE MANAGEMENT ====================

  // Get all vehicles
  Future<Map<String, dynamic>> getVehicles({
    String? status,
    String? type,
    int perPage = 15,
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey = 'vehicles:${status ?? 'all'}:${type ?? 'all'}:$perPage';
      return await _cachedMapRequest(
        key: cacheKey,
        ttl: const Duration(seconds: 45),
        forceRefresh: forceRefresh,
        request: () => _apiService.getVehicles(
          status: status,
          type: type,
          perPage: perPage,
        ),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Create new vehicle
  Future<bool> createVehicle({
    required String name,
    required String numberPlate,
    required String type,
    required int hourlyRate,
    required int dailyRate,
    required int weeklyRate,
    required String description,
    required List<String> features,
    String status = 'available',
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.createVehicle(
        name: name,
        numberPlate: numberPlate,
        type: type,
        hourlyRate: hourlyRate,
        dailyRate: dailyRate,
        weeklyRate: weeklyRate,
        description: description,
        features: features,
        status: status,
      );

      _setLoading(false);
      if (response['success'] == true) {
        _invalidateVehicleCache();
        await refreshUser();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to create vehicle';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error creating vehicle: $e';
      _setLoading(false);
      return false;
    }
  }

  // Get vehicle details
  Future<Map<String, dynamic>> getVehicleDetails(String vehicleId) async {
    try {
      return await _apiService.getVehicleDetails(vehicleId);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Update vehicle

// Update vehicle
  Future<bool> updateVehicle(
    String vehicleId, {
    String? name,
    int? hourlyRate,
    int? dailyRate,
    int? weeklyRate, // ADD THIS
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.updateVehicle(
        vehicleId,
        name: name,
        hourlyRate: hourlyRate,
        dailyRate: dailyRate,
        weeklyRate: weeklyRate, // ADD THIS
      );

      _setLoading(false);
      if (response['success'] == true) {
        _invalidateVehicleCache();
        await refreshUser();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to update vehicle';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error updating vehicle: $e';
      _setLoading(false);
      return false;
    }
  }

  // Update vehicle status
  Future<bool> updateVehicleStatus(
    String vehicleId, {
    required String status,
    String? reason,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.updateVehicleStatus(
        vehicleId,
        status: status,
        reason: reason,
      );

      _setLoading(false);
      if (response['success'] == true) {
        _invalidateVehicleCache();
        return true;
      } else {
        _errorMessage =
            response['message'] ?? 'Failed to update vehicle status';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error updating status: $e';
      _setLoading(false);
      return false;
    }
  }

  // Get available vehicles
  Future<Map<String, dynamic>> getAvailableVehicles({
    String? type,
    int? minPrice,
    int? maxPrice,
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey =
          'availableVehicles:${type ?? 'all'}:${minPrice ?? 'na'}:${maxPrice ?? 'na'}';
      return await _cachedMapRequest(
        key: cacheKey,
        ttl: const Duration(seconds: 30),
        forceRefresh: forceRefresh,
        request: () => _apiService.getAvailableVehicles(
          type: type,
          minPrice: minPrice,
          maxPrice: maxPrice,
        ),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get vehicle statistics
  Future<Map<String, dynamic>> getVehicleStatistics(String vehicleId) async {
    try {
      return await _apiService.getVehicleStatistics(vehicleId);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Delete vehicle
  Future<bool> deleteVehicle(String vehicleId) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.deleteVehicle(vehicleId);

      _setLoading(false);
      if (response['success'] == true) {
        _invalidateVehicleCache();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to delete vehicle';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error deleting vehicle: $e';
      _setLoading(false);
      return false;
    }
  }

  // ==================== RENTAL MANAGEMENT ====================

  // Phase 1: Verify DL & Save Customer
  Future<Map<String, dynamic>> verifyDLAndSaveCustomer({
    required String vehicleId,
    required String customerPhone,
    required String dlNumber,
    required String dob,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.verifyDLAndSaveCustomer(
        vehicleId: vehicleId,
        customerPhone: customerPhone,
        dlNumber: dlNumber,
        dob: dob,
      );

      _setLoading(false);
      if (response['success'] == true) {
        _invalidateWalletCache();
        _invalidateRentalCache();
        _invalidateCustomersCache();
      }
      return response;
    } catch (e) {
      _errorMessage = 'Error verifying DL: $e';
      _setLoading(false);
      return {'success': false, 'message': e.toString()};
    }
  }

  // Phase 2: Upload rental documents
  Future<Map<String, dynamic>> uploadDocuments({
    required String verificationToken,
    required File licenseImage,
    File? aadhaarImage,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.uploadDocuments(
        verificationToken: verificationToken,
        licenseImage: licenseImage,
        aadhaarImage: aadhaarImage,
      );

      _setLoading(false);
      if (response['success'] == true) {
        _invalidateRentalCache();
      }
      return response;
    } catch (e) {
      _errorMessage = 'Error uploading documents: $e';
      _setLoading(false);
      return {'success': false, 'message': e.toString()};
    }
  }

  // Phase 3: Sign agreement & handover vehicle
  Future<Map<String, dynamic>> signAndHandover({
    required int rentalId,
    required File signedAgreementImage,
    File? customerWithVehicleImage,
    File? vehicleConditionVideo,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.signAndHandover(
        rentalId: rentalId,
        signedAgreementImage: signedAgreementImage,
        customerWithVehicleImage: customerWithVehicleImage,
        vehicleConditionVideo: vehicleConditionVideo,
      );

      _setLoading(false);
      if (response['success'] == true) {
        _invalidateVehicleCache();
        _invalidateRentalCache();
      }
      return response;
    } catch (e) {
      _errorMessage = 'Error during sign & handover: $e';
      _setLoading(false);
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get active rentals
  Future<Map<String, dynamic>> getActiveRentals({
    bool forceRefresh = false,
  }) async {
    try {
      return await _cachedMapRequest(
        key: 'rentals:active',
        ttl: const Duration(seconds: 20),
        forceRefresh: forceRefresh,
        request: () => _apiService.getActiveRentals(),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get rental history
  Future<Map<String, dynamic>> getRentalHistory({
    int perPage = 15,
    String? status,
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey = 'rentals:history:$perPage:${status ?? 'all'}';
      return await _cachedMapRequest(
        key: cacheKey,
        ttl: const Duration(seconds: 30),
        forceRefresh: forceRefresh,
        request: () =>
            _apiService.getRentalHistory(perPage: perPage, status: status),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get rental details
  Future<Map<String, dynamic>> getRentalDetails(
    String rentalId, {
    bool forceRefresh = false,
  }) async {
    try {
      return await _cachedMapRequest(
        key: 'rentalDetails:$rentalId',
        ttl: const Duration(seconds: 20),
        forceRefresh: forceRefresh,
        request: () => _apiService.getRentalDetails(rentalId),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get rental statistics
  Future<Map<String, dynamic>> getRentalStatistics({
    bool forceRefresh = false,
  }) async {
    try {
      return await _cachedMapRequest(
        key: 'rentalStats:summary',
        ttl: const Duration(seconds: 45),
        forceRefresh: forceRefresh,
        request: () => _apiService.getRentalStatistics(),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Cancel rental
  Future<Map<String, dynamic>> cancelRental(String rentalId) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.cancelRental(rentalId);

      _setLoading(false);
      if (response['success'] != true) {
        _errorMessage = response['message'] ?? 'Failed to cancel rental';
      } else {
        _invalidateRentalCache();
        _invalidateVehicleCache();
        _invalidateWalletCache();
      }
      return response;
    } catch (e) {
      _errorMessage = 'Error cancelling rental: $e';
      _setLoading(false);
      return {'success': false, 'message': e.toString()};
    }
  }

  // Return vehicle with optional damage details
  Future<Map<String, dynamic>> returnVehicle({
    required int rentalId,
    required bool vehicleInGoodCondition,
    int? damageAmount,
    String? damageDescription,
    List<File>? damageImages,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.returnVehicle(
        rentalId: rentalId,
        vehicleInGoodCondition: vehicleInGoodCondition,
        damageAmount: damageAmount,
        damageDescription: damageDescription,
        damageImages: damageImages,
      );
      _setLoading(false);
      if (response['success'] != true) {
        _errorMessage = response['message'] ?? 'Failed to return vehicle';
      } else {
        _invalidateRentalCache();
        _invalidateVehicleCache();
        _invalidateWalletCache();
      }
      return response;
    } catch (e) {
      _errorMessage = 'Error returning vehicle: $e';
      _setLoading(false);
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get receipt for completed rental
  Future<Map<String, dynamic>> getRentalReceipt(String rentalId) async {
    try {
      return await _apiService.getRentalReceipt(rentalId);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get signed agreement for active/completed rental
  Future<Map<String, dynamic>> getSignedAgreement(String rentalId) async {
    try {
      return await _apiService.getSignedAgreement(rentalId);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get rental phase status
  Future<Map<String, dynamic>> getRentalPhaseStatus(
    String rentalId, {
    bool forceRefresh = false,
  }) async {
    try {
      return await _cachedMapRequest(
        key: 'rentalPhase:$rentalId',
        ttl: const Duration(seconds: 10),
        forceRefresh: forceRefresh,
        request: () => _apiService.getRentalPhaseStatus(rentalId),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== WALLET MANAGEMENT ====================

  // Get wallet balance
  Future<int> getWalletBalance({bool forceRefresh = false}) async {
    try {
      final response = await _cachedMapRequest(
        key: 'wallet:balance',
        ttl: const Duration(seconds: 20),
        forceRefresh: forceRefresh,
        request: () => _apiService.getWalletBalance(),
      );
      if (response['success'] == true && response['data']?['balance'] != null) {
        if (_user != null) {
          _user!.walletBalance = response['data']['balance'];
          notifyListeners();
        }
        return response['data']['balance'];
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> fetchWalletBalance() async {
    try {
      await getWalletBalance(forceRefresh: true);
    } catch (e) {
      print('Fetch wallet error: $e');
    }
  }

  // Get wallet transactions
  Future<Map<String, dynamic>> getWalletTransactions({
    String? type,
    String? status,
    int perPage = 20,
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey = 'wallet:tx:${type ?? 'all'}:${status ?? 'all'}:$perPage';
      return await _cachedMapRequest(
        key: cacheKey,
        ttl: const Duration(seconds: 15),
        forceRefresh: forceRefresh,
        request: () => _apiService.getWalletTransactions(
          type: type,
          status: status,
          perPage: perPage,
        ),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get transaction details
  Future<Map<String, dynamic>> getTransactionDetails(
      String transactionId) async {
    try {
      return await _apiService.getTransactionDetails(transactionId);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Transfer money
  Future<bool> transferMoney({
    required String recipientPhone,
    required int amount,
    required String reason,
    String? notes,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.transferMoney(
        recipientPhone: recipientPhone,
        amount: amount,
        reason: reason,
        notes: notes,
      );

      _setLoading(false);
      if (response['success'] == true) {
        _invalidateWalletCache();
        await getWalletBalance();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Transfer failed';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error transferring money: $e';
      _setLoading(false);
      return false;
    }
  }

  // Get wallet statement
  Future<Map<String, dynamic>> getWalletStatement({
    required String startDate,
    required String endDate,
    String format = 'json',
  }) async {
    try {
      return await _apiService.getWalletStatement(
        startDate: startDate,
        endDate: endDate,
        format: format,
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Initiate recharge
  Future<Map<String, dynamic>> initiateRecharge({
    required int amount,
    required String paymentMethod,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.initiateRecharge(
        amount: amount,
        paymentMethod: paymentMethod,
      );

      _setLoading(false);
      if (response['success'] == true) {
        _invalidateWalletCache();
      }
      return response;
    } catch (e) {
      _errorMessage = 'Error initiating recharge: $e';
      _setLoading(false);
      return {'success': false, 'message': e.toString()};
    }
  }

  // Check payment status
  Future<Map<String, dynamic>> checkPaymentStatus(String orderId) async {
    try {
      return await _apiService.checkPaymentStatus(orderId);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== REPORTS MANAGEMENT ====================

  // Get reports summary
  Future<Map<String, dynamic>> getReportsSummary({
    bool forceRefresh = false,
  }) async {
    try {
      return await _cachedMapRequest(
        key: 'reports:summary',
        ttl: const Duration(minutes: 5),
        forceRefresh: forceRefresh,
        request: () => _apiService.getReportsSummary(),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get earnings report
  Future<Map<String, dynamic>> getReportsEarnings({
    String? startDate,
    String? endDate,
    String? month,
    String? year,
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey =
          'reports:earnings:${startDate ?? 'na'}:${endDate ?? 'na'}:${month ?? 'na'}:${year ?? 'na'}';
      return await _cachedMapRequest(
        key: cacheKey,
        ttl: const Duration(minutes: 5),
        forceRefresh: forceRefresh,
        request: () => _apiService.getReportsEarnings(
          startDate: startDate,
          endDate: endDate,
          month: month,
          year: year,
        ),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get rentals report
  Future<Map<String, dynamic>> getReportsRentals({
    String? startDate,
    String? endDate,
    String? date,
    String? status,
    String? vehicleId,
    String? customerId,
    String? sortBy,
    String? sortOrder,
    int perPage = 15,
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey =
          'reports:rentals:${startDate ?? 'na'}:${endDate ?? 'na'}:${date ?? 'na'}:${status ?? 'na'}:${vehicleId ?? 'na'}:${customerId ?? 'na'}:$perPage';
      return await _cachedMapRequest(
        key: cacheKey,
        ttl: const Duration(minutes: 3),
        forceRefresh: forceRefresh,
        request: () => _apiService.getReportsRentals(
          startDate: startDate,
          endDate: endDate,
          date: date,
          status: status,
          vehicleId: vehicleId,
          customerId: customerId,
          sortBy: sortBy,
          sortOrder: sortOrder,
          perPage: perPage,
        ),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get top vehicles report
  Future<Map<String, dynamic>> getReportsTopVehicles({
    int limit = 10,
    String? period,
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey = 'reports:topVehicles:$limit:${period ?? 'all_time'}';
      return await _cachedMapRequest(
        key: cacheKey,
        ttl: const Duration(minutes: 10),
        forceRefresh: forceRefresh,
        request: () => _apiService.getReportsTopVehicles(
          limit: limit,
          period: period,
        ),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get top customers report
  Future<Map<String, dynamic>> getReportsTopCustomers({
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey = 'reports:topCustomers:$limit';
      return await _cachedMapRequest(
        key: cacheKey,
        ttl: const Duration(minutes: 10),
        forceRefresh: forceRefresh,
        request: () => _apiService.getReportsTopCustomers(limit: limit),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get documents report
  Future<Map<String, dynamic>> getReportsDocuments({
    bool forceRefresh = false,
  }) async {
    try {
      return await _cachedMapRequest(
        key: 'reports:documents',
        ttl: const Duration(minutes: 5),
        forceRefresh: forceRefresh,
        request: () => _apiService.getReportsDocuments(),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Export rentals report
  Future<Map<String, dynamic>> exportRentalsReport({
    String? startDate,
    String? endDate,
    String? date,
    String? status,
    String? vehicleId,
    String? customerId,
    String? sortBy,
    String? sortOrder,
    String format = 'csv',
  }) async {
    try {
      return await _apiService.exportRentalsReport(
        startDate: startDate,
        endDate: endDate,
        date: date,
        status: status,
        vehicleId: vehicleId,
        customerId: customerId,
        sortBy: sortBy,
        sortOrder: sortOrder,
        format: format,
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== BUSINESS PROFILE MANAGEMENT ====================

  // Update Business Display Info (API 3.6)
  Future<bool> updateBusinessDisplay({
    required String displayName,
    required String displayAddress,
    required String phone,
    required String email,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.updateBusinessDisplay(
        displayName: displayName,
        displayAddress: displayAddress,
        phone: phone,
        email: email,
      );

      _setLoading(false);
      if (response['success'] == true) {
        _invalidateBusinessCache();
        await refreshUser();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to update business info';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error updating business info: $e';
      _setLoading(false);
      return false;
    }
  }

  // Update Business Location (API 3.10)
  Future<bool> updateBusinessLocation({
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.updateBusinessLocation(
        latitude: latitude,
        longitude: longitude,
        address: address,
      );

      _setLoading(false);
      if (response['success'] == true) {
        _invalidateBusinessCache();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to update location';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error updating location: $e';
      _setLoading(false);
      return false;
    }
  }

  // Add/Verify GST Number (API 3.8)
  Future<bool> addGstNumber({
    required String gstNumber,
    required String businessName,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.addGstNumber(
        gstNumber: gstNumber,
        businessName: businessName,
      );

      _setLoading(false);
      if (response['success'] == true) {
        _invalidateBusinessCache();
        await refreshUser();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'GST verification failed';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error verifying GST: $e';
      _setLoading(false);
      return false;
    }
  }

  // Get GST Status (API 3.9)
  Future<Map<String, dynamic>> getGstStatus({bool forceRefresh = false}) async {
    try {
      return await _cachedMapRequest(
        key: 'business:gst',
        ttl: const Duration(minutes: 30),
        forceRefresh: forceRefresh,
        request: () => _apiService.getGstStatus(),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get Business Verification Status (API 3.7)
  Future<Map<String, dynamic>> getBusinessVerificationStatus(
      {bool forceRefresh = false}) async {
    try {
      return await _cachedMapRequest(
        key: 'business:verification',
        ttl: const Duration(minutes: 15),
        forceRefresh: forceRefresh,
        request: () => _apiService.getBusinessVerificationStatus(),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Upload Business Logo (API 3.11)
  Future<bool> uploadBusinessLogo(File logoFile) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.uploadBusinessLogo(logoFile);

      _setLoading(false);
      if (response['success'] == true) {
        _invalidateBusinessCache();
        await refreshUser();
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to upload logo';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error uploading logo: $e';
      _setLoading(false);
      return false;
    }
  }

  // ==================== SETTINGS MANAGEMENT ====================

  // Get all settings (API 11.1)
  Future<Map<String, dynamic>> getSettings({bool forceRefresh = false}) async {
    try {
      return await _cachedMapRequest(
        key: 'settings:all',
        ttl: const Duration(minutes: 10),
        forceRefresh: forceRefresh,
        request: () => _apiService.getSettings(),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Update single setting (API 11.4)
  Future<bool> updateSetting(String key, dynamic value, String type) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.updateSetting(key, value, type);

      _setLoading(false);
      if (response['success'] == true) {
        _invalidateCacheByPrefix('settings:');
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to update setting';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error updating setting: $e';
      _setLoading(false);
      return false;
    }
  }

  // Update multiple settings (API 11.2)
  Future<bool> updateMultipleSettings(
      Map<String, Map<String, dynamic>> settings) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.updateMultipleSettings(settings);

      _setLoading(false);
      if (response['success'] == true) {
        _invalidateCacheByPrefix('settings:');
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to update settings';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error updating settings: $e';
      _setLoading(false);
      return false;
    }
  }

  // Get specific setting (API 11.3)
  Future<Map<String, dynamic>> getSetting(String key,
      {bool forceRefresh = false}) async {
    try {
      return await _cachedMapRequest(
        key: 'settings:$key',
        ttl: const Duration(minutes: 10),
        forceRefresh: forceRefresh,
        request: () => _apiService.getSetting(key),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Reset settings (API 11.9)
  Future<bool> resetSettings({List<String>? keys, bool all = false}) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.resetSettings(keys: keys, all: all);

      _setLoading(false);
      if (response['success'] == true) {
        _invalidateCacheByPrefix('settings:');
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to reset settings';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error resetting settings: $e';
      _setLoading(false);
      return false;
    }
  }

  // ==================== LEGAL PAGES ====================

  // Get all legal pages
  Future<Map<String, dynamic>> getLegalPages(
      {bool forceRefresh = false}) async {
    try {
      return await _cachedMapRequest(
        key: 'legal:pages',
        ttl: const Duration(days: 7), // Legal pages don't change often
        forceRefresh: forceRefresh,
        request: () => _apiService.getLegalPages(),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get specific legal page
  Future<Map<String, dynamic>> getLegalPage(String slug,
      {bool forceRefresh = false}) async {
    try {
      return await _cachedMapRequest(
        key: 'legal:page:$slug',
        ttl: const Duration(days: 7),
        forceRefresh: forceRefresh,
        request: () => _apiService.getLegalPage(slug),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== CUSTOMER MANAGEMENT ====================

  // Get all customers (API 5.1)
  Future<Map<String, dynamic>> getCustomers({
    int perPage = 20,
    String? search,
    String? sortBy,
    String? sortOrder,
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey =
          'customers:list:$perPage:${search ?? 'none'}:${sortBy ?? 'none'}:${sortOrder ?? 'none'}';
      return await _cachedMapRequest(
        key: cacheKey,
        ttl: const Duration(seconds: 30),
        forceRefresh: forceRefresh,
        request: () => _apiService.getCustomers(
          perPage: perPage,
          search: search,
          sortBy: sortBy,
          sortOrder: sortOrder,
        ),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Search customers (API 5.2)
  Future<Map<String, dynamic>> searchCustomers(String query,
      {bool forceRefresh = false}) async {
    try {
      final cacheKey = 'customers:search:$query';
      return await _cachedMapRequest(
        key: cacheKey,
        ttl: const Duration(seconds: 15),
        forceRefresh: forceRefresh,
        request: () => _apiService.searchCustomers(query),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get customer details (API 5.3)
  Future<Map<String, dynamic>> getCustomerDetails(int customerId,
      {bool forceRefresh = false}) async {
    try {
      final cacheKey = 'customers:details:$customerId';
      return await _cachedMapRequest(
        key: cacheKey,
        ttl: const Duration(minutes: 5),
        forceRefresh: forceRefresh,
        request: () => _apiService.getCustomerDetails(customerId),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get customer rental history (API 5.6)
  Future<Map<String, dynamic>> getCustomerRentalHistory(
    int customerId, {
    int perPage = 15,
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey = 'customers:rentals:$customerId:$perPage';
      return await _cachedMapRequest(
        key: cacheKey,
        ttl: const Duration(seconds: 20),
        forceRefresh: forceRefresh,
        request: () =>
            _apiService.getCustomerRentalHistory(customerId, perPage: perPage),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get customer statistics (API 5.5)
  Future<Map<String, dynamic>> getCustomerStatistics(int customerId,
      {bool forceRefresh = false}) async {
    try {
      final cacheKey = 'customers:stats:$customerId';
      return await _cachedMapRequest(
        key: cacheKey,
        ttl: const Duration(minutes: 10),
        forceRefresh: forceRefresh,
        request: () => _apiService.getCustomerStatistics(customerId),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get customers with incomplete documentation (API 5.7)
  Future<Map<String, dynamic>> getCustomersIncompleteDocs(
      {int perPage = 20, bool forceRefresh = false}) async {
    try {
      final cacheKey = 'customers:incomplete:$perPage';
      return await _cachedMapRequest(
        key: cacheKey,
        ttl: const Duration(seconds: 30),
        forceRefresh: forceRefresh,
        request: () => _apiService.getCustomersIncompleteDocs(perPage: perPage),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get verified customers (API 5.8)
  Future<Map<String, dynamic>> getVerifiedCustomers(
      {int perPage = 20, bool forceRefresh = false}) async {
    try {
      final cacheKey = 'customers:verified:$perPage';
      return await _cachedMapRequest(
        key: cacheKey,
        ttl: const Duration(seconds: 30),
        forceRefresh: forceRefresh,
        request: () => _apiService.getVerifiedCustomers(perPage: perPage),
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== UTILITIES ====================

  // Refresh user data
  Future<void> refreshUser() async {
    try {
      final response = await _apiService.getCurrentUser();
      if (response['success'] == true && response['data']?['user'] != null) {
        _user = User.fromJson(response['data']['user']);
        notifyListeners();
      } else if (response['unauthorized'] == true) {
        await handleUnauthorized();
      }
    } catch (e) {
      print('Refresh user error: $e');
    }
  }

  Future<void> loadStoredAuthData() async {
    try {
      // Load token from secure storage
      final token = await _apiService.getStoredToken();

      if (token != null && token.isNotEmpty) {
        _token = token;

        // Load user data from storage
        final userData = await _apiService.getStoredUserData();
        if (userData != null) {
          _user = User.fromJson(userData);
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error loading stored auth data: $e');
    }
  }

  // Clear all caches
  void clearAllCaches() {
    _responseCache.clear();
    _inFlightRequests.clear();
    notifyListeners();
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
      _responseCache.clear();
      _inFlightRequests.clear();
    } catch (e) {
      print('Logout error: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Check if token is valid on app resume
  Future<bool> validateToken() async {
    if (_token == null) return false;

    try {
      final response = await _apiService.getCurrentUser();
      if (response['success'] == true) {
        // Token is valid, update user data
        if (response['data']?['user'] != null) {
          _user = User.fromJson(response['data']['user']);
          notifyListeners();
        }
        return true;
      } else if (response['unauthorized'] == true ||
          response['status_code'] == 401 ||
          response['message']?.toString().contains('Unauthenticated') == true) {
        // Token invalid
        await logout();
        return false;
      }
      return true;
    } catch (e) {
      // Network error, assume token is still valid but show warning
      print('Token validation error: $e');
      return true;
    }
  }

// Auto logout on 401 response from any API call
  Future<void> handleUnauthorized() async {
    await logout();
    // Emit unauthorized event to all listeners
    _unauthorizedController.add(null);
    // Notify via navigator key if available
    if (ApiInterceptor.navigatorKey.currentContext != null) {
      // Use WidgetsBinding to ensure it's called after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ApiInterceptor.handleUnauthorized(
            ApiInterceptor.navigatorKey.currentContext!);
      });
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

  @override
  void dispose() {
    _unauthorizedController.close();
    super.dispose();
  }

  // Change password
  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        newPasswordConfirmation: newPasswordConfirmation,
      );

      _setLoading(false);
      if (response['success'] == true) {
        // Update token if returned
        if (response['data']?['new_token'] != null) {
          _token = response['data']['new_token'];
        }
        return true;
      } else {
        _errorMessage = response['message'] ?? 'Failed to change password';
        return false;
      }
    } catch (e) {
      _errorMessage = 'Network error: $e';
      _setLoading(false);
      return false;
    }
  }
}
