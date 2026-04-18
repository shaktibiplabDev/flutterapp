import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:io';

class ApiService {
  static const String baseUrl =
      'https://rentos.versaero.top/api'; // Update with your API URL

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

  // Multipart Headers
  Future<Map<String, String>> getMultipartHeaders() async {
    final token = await _storage.read(key: 'user_token');
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  bool _startsWithPdf(Uint8List bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46; // F
  }

  Map<String, dynamic>? _tryDecodeJsonMap(String value) {
    try {
      final decoded = json.decode(value);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  String _unwrapQuotedString(String value) {
    final trimmed = value.trim();
    if ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
        (trimmed.startsWith("'") && trimmed.endsWith("'"))) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed;
  }

  bool _looksLikeHex(String value) {
    final normalized = value
        .replaceAll(RegExp(r'\s+'), '')
        .replaceFirst(RegExp(r'^0x', caseSensitive: false), '');
    if (normalized.length < 2 || normalized.length.isOdd) return false;
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(normalized);
  }

  Uint8List _decodeHex(String value) {
    final normalized = value
        .replaceAll(RegExp(r'\s+'), '')
        .replaceFirst(RegExp(r'^0x', caseSensitive: false), '');
    final out = Uint8List(normalized.length ~/ 2);
    for (int i = 0; i < normalized.length; i += 2) {
      out[i ~/ 2] = int.parse(normalized.substring(i, i + 2), radix: 16);
    }
    return out;
  }

  String? _extractFileNameFromContentDisposition(String? headerValue) {
    if (headerValue == null || headerValue.isEmpty) return null;
    final utf8Match =
        RegExp(r"filename\*=UTF-8''([^;]+)", caseSensitive: false)
            .firstMatch(headerValue);
    if (utf8Match != null) {
      return Uri.decodeComponent(utf8Match.group(1)!);
    }
    final quotedMatch =
        RegExp(r'filename="([^"]+)"', caseSensitive: false).firstMatch(
      headerValue,
    );
    if (quotedMatch != null) return quotedMatch.group(1);
    final plainMatch =
        RegExp(r'filename=([^;]+)', caseSensitive: false).firstMatch(
      headerValue,
    );
    return plainMatch?.group(1)?.trim();
  }

  Map<String, dynamic> _buildBinaryDocumentResponse(
    Uint8List bytes, {
    String? fileName,
    String? mimeType,
  }) {
    return {
      'success': true,
      'data': {
        'bytes_base64': base64Encode(bytes),
        'file_name': fileName ?? 'document.pdf',
        'mime_type': mimeType ?? 'application/pdf',
      },
    };
  }

  Future<Map<String, dynamic>> _fetchRentalDocument(
    String endpointPath, {
    required String fallbackFileName,
  }) async {
    final headers = await getHeaders();
    headers['Accept'] = 'application/pdf,application/json,text/plain,*/*';
    final response = await http.get(
      Uri.parse('$baseUrl$endpointPath'),
      headers: headers,
    );

    final bytes = response.bodyBytes;
    final contentType = response.headers['content-type']?.toLowerCase() ?? '';
    final fileName = _extractFileNameFromContentDisposition(
          response.headers['content-disposition'],
        ) ??
        fallbackFileName;

    if (response.statusCode >= 400) {
      final jsonMap = _tryDecodeJsonMap(response.body);
      if (jsonMap != null) return jsonMap;
      return {
        'success': false,
        'message': 'Failed to download document (${response.statusCode})',
      };
    }

    if (bytes.isEmpty) {
      return {'success': false, 'message': 'Empty document response'};
    }

    if (contentType.contains('application/json')) {
      final jsonMap = _tryDecodeJsonMap(response.body);
      if (jsonMap != null) return jsonMap;
    }

    if (_startsWithPdf(bytes) ||
        contentType.contains('application/pdf') ||
        contentType.contains('application/octet-stream')) {
      return _buildBinaryDocumentResponse(
        bytes,
        fileName: fileName,
        mimeType: contentType.isEmpty ? null : contentType,
      );
    }

    final rawText = utf8.decode(bytes, allowMalformed: true).trim();
    if (rawText.isNotEmpty) {
      final jsonMap = _tryDecodeJsonMap(rawText);
      if (jsonMap != null) return jsonMap;

      final normalized = _unwrapQuotedString(rawText);

      if (_looksLikeHex(normalized)) {
        final decoded = _decodeHex(normalized);
        if (decoded.isNotEmpty) {
          return _buildBinaryDocumentResponse(
            decoded,
            fileName: fileName,
            mimeType: 'application/pdf',
          );
        }
      }

      try {
        final decoded = base64Decode(normalized);
        if (decoded.isNotEmpty) {
          return _buildBinaryDocumentResponse(
            decoded,
            fileName: fileName,
            mimeType: 'application/pdf',
          );
        }
      } catch (_) {}
    }

    return _buildBinaryDocumentResponse(
      bytes,
      fileName: fileName,
      mimeType: contentType.isEmpty ? null : contentType,
    );
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
      await _storage.write(
          key: 'user_data', value: json.encode(data['data']['user']));
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
        await _storage.write(
            key: 'user_data', value: json.encode(userData['data']['user']));
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
      await _storage.write(
          key: 'user_data', value: json.encode(data['data']['user']));
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
      await _storage.write(
          key: 'user_data', value: json.encode(data['data']['user']));
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
      await _storage.write(
          key: 'user_data', value: json.encode(data['data']['user']));
    }

    return data;
  }

  // ==================== VEHICLE MANAGEMENT ====================

  // Get all vehicles with filters
  Future<Map<String, dynamic>> getVehicles({
    String? status,
    String? type,
    int perPage = 15,
  }) async {
    final headers = await getHeaders();
    final queryParams = <String, String>{};
    if (status != null) queryParams['status'] = status;
    if (type != null) queryParams['type'] = type;
    queryParams['per_page'] = perPage.toString();

    final uri =
        Uri.parse('$baseUrl/vehicles').replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);

    return json.decode(response.body);
  }

  // Create new vehicle
  Future<Map<String, dynamic>> createVehicle({
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
    final headers = await getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/vehicles'),
      headers: headers,
      body: json.encode({
        'name': name,
        'number_plate': numberPlate,
        'type': type,
        'hourly_rate': hourlyRate,
        'daily_rate': dailyRate,
        'weekly_rate': weeklyRate,
        'description': description,
        'features': features,
        'status': status,
      }),
    );

    return json.decode(response.body);
  }

  // Get vehicle details
  Future<Map<String, dynamic>> getVehicleDetails(String vehicleId) async {
    final headers = await getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/vehicles/$vehicleId'),
      headers: headers,
    );

    return json.decode(response.body);
  }

  // Update vehicle
  Future<Map<String, dynamic>> updateVehicle(
    String vehicleId, {
    String? name,
    int? hourlyRate,
    int? dailyRate,
  }) async {
    final headers = await getHeaders();
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (hourlyRate != null) body['hourly_rate'] = hourlyRate;
    if (dailyRate != null) body['daily_rate'] = dailyRate;

    final response = await http.put(
      Uri.parse('$baseUrl/vehicles/$vehicleId'),
      headers: headers,
      body: json.encode(body),
    );

    return json.decode(response.body);
  }

  // Update vehicle status
  Future<Map<String, dynamic>> updateVehicleStatus(
    String vehicleId, {
    required String status,
    String? reason,
  }) async {
    final headers = await getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/vehicles/$vehicleId/status'),
      headers: headers,
      body: json.encode({
        'status': status,
        if (reason != null) 'reason': reason,
      }),
    );

    return json.decode(response.body);
  }

  // Get available vehicles with filters
  Future<Map<String, dynamic>> getAvailableVehicles({
    String? type,
    int? minPrice,
    int? maxPrice,
  }) async {
    final headers = await getHeaders();
    final queryParams = <String, String>{};
    if (type != null) queryParams['type'] = type;
    if (minPrice != null) queryParams['min_price'] = minPrice.toString();
    if (maxPrice != null) queryParams['max_price'] = maxPrice.toString();

    final uri = Uri.parse('$baseUrl/vehicles/available')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);

    return json.decode(response.body);
  }

  // Get vehicle statistics
  Future<Map<String, dynamic>> getVehicleStatistics(String vehicleId) async {
    final headers = await getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/vehicles/$vehicleId/statistics'),
      headers: headers,
    );

    return json.decode(response.body);
  }

  // Delete vehicle
  Future<Map<String, dynamic>> deleteVehicle(String vehicleId) async {
    final headers = await getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/vehicles/$vehicleId'),
      headers: headers,
    );

    return json.decode(response.body);
  }

  // ==================== RENTAL MANAGEMENT ====================

  // Phase 1: Verify DL & Save Customer
  Future<Map<String, dynamic>> verifyDLAndSaveCustomer({
    required String vehicleId,
    required String customerPhone,
    required String dlNumber,
    required String dob,
  }) async {
    final headers = await getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/rentals/phase1/verify'),
      headers: headers,
      body: json.encode({
        'vehicle_id': vehicleId,
        'customer_phone': customerPhone,
        'dl_number': dlNumber,
        'dob': dob,
      }),
    );

    return json.decode(response.body);
  }

  // Phase 2: Upload Documents
  Future<Map<String, dynamic>> uploadDocuments({
    required String verificationToken,
    required File licenseImage,
    File? aadhaarImage,
  }) async {
    final headers = await getMultipartHeaders();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/rentals/phase2/documents'),
    );
    
    request.headers.addAll(headers);
    request.fields['verification_token'] = verificationToken;
    
    // Add license image
    final licenseFile = await http.MultipartFile.fromPath(
      'license_image',
      licenseImage.path,
      contentType: MediaType('image', 'jpeg'),
    );
    request.files.add(licenseFile);
    
    // Add aadhaar image if provided
    if (aadhaarImage != null) {
      final aadhaarFile = await http.MultipartFile.fromPath(
        'aadhaar_image',
        aadhaarImage.path,
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(aadhaarFile);
    }
    
    final response = await request.send();
    final responseBody = await http.Response.fromStream(response);
    return json.decode(responseBody.body);
  }

  // Phase 3: Sign & Handover
  Future<Map<String, dynamic>> signAndHandover({
    required int rentalId,
    required File signedAgreementImage,
    File? customerWithVehicleImage,
    File? vehicleConditionVideo,
  }) async {
    final headers = await getMultipartHeaders();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/rentals/$rentalId/phase3/sign'),
    );
    
    request.headers.addAll(headers);
    
    // Add signed agreement image
    final signedAgreementFile = await http.MultipartFile.fromPath(
      'signed_agreement_image',
      signedAgreementImage.path,
      contentType: MediaType('image', 'jpeg'),
    );
    request.files.add(signedAgreementFile);
    
    // Add customer with vehicle image if provided
    if (customerWithVehicleImage != null) {
      final customerImageFile = await http.MultipartFile.fromPath(
        'customer_with_vehicle_image',
        customerWithVehicleImage.path,
        contentType: MediaType('image', 'jpeg'),
      );
      request.files.add(customerImageFile);
    }
    
    // Add vehicle condition video if provided
    if (vehicleConditionVideo != null) {
      final videoFile = await http.MultipartFile.fromPath(
        'vehicle_condition_video',
        vehicleConditionVideo.path,
        contentType: MediaType('video', 'mp4'),
      );
      request.files.add(videoFile);
    }
    
    final response = await request.send();
    final responseBody = await http.Response.fromStream(response);
    return json.decode(responseBody.body);
  }

  // Get rental phase status
  Future<Map<String, dynamic>> getRentalPhaseStatus(String rentalId) async {
    final headers = await getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/rentals/$rentalId/phase-status'),
      headers: headers,
    );

    return json.decode(response.body);
  }

  // Get active rentals
  Future<Map<String, dynamic>> getActiveRentals() async {
    final headers = await getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/rentals/active'),
      headers: headers,
    );

    return json.decode(response.body);
  }

  // Get rental history
  Future<Map<String, dynamic>> getRentalHistory({
    int perPage = 15,
    String? status,
  }) async {
    final headers = await getHeaders();
    final queryParams = <String, String>{};
    queryParams['per_page'] = perPage.toString();
    if (status != null) queryParams['status'] = status;

    final uri = Uri.parse('$baseUrl/rentals/history')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);

    return json.decode(response.body);
  }

  // Get rental details
  Future<Map<String, dynamic>> getRentalDetails(String rentalId) async {
    final headers = await getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/rentals/$rentalId'),
      headers: headers,
    );

    return json.decode(response.body);
  }

  // Get rental statistics
  Future<Map<String, dynamic>> getRentalStatistics() async {
    final headers = await getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/rentals/statistics'),
      headers: headers,
    );

    return json.decode(response.body);
  }

  // Cancel rental
  Future<Map<String, dynamic>> cancelRental(String rentalId) async {
    final headers = await getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/rentals/$rentalId/cancel'),
      headers: headers,
    );

    return json.decode(response.body);
  }

  // Return vehicle
  Future<Map<String, dynamic>> returnVehicle({
    required int rentalId,
    required bool vehicleInGoodCondition,
    int? damageAmount,
    String? damageDescription,
    List<File>? damageImages,
  }) async {
    final headers = await getMultipartHeaders();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/rentals/$rentalId/return'),
    );
    
    request.headers.addAll(headers);
    request.fields['vehicle_in_good_condition'] = vehicleInGoodCondition ? '1' : '0';
    
    if (damageAmount != null) {
      request.fields['damage_amount'] = damageAmount.toString();
    }
    if (damageDescription != null) {
      request.fields['damage_description'] = damageDescription;
    }
    
    if (damageImages != null && damageImages.isNotEmpty) {
      for (final image in damageImages) {
        final damageFile = await http.MultipartFile.fromPath(
          'damage_images[]',
          image.path,
          contentType: MediaType('image', 'jpeg'),
        );
        request.files.add(damageFile);
      }
    }
    
    final response = await request.send();
    final responseBody = await http.Response.fromStream(response);
    return json.decode(responseBody.body);
  }

  // Get receipt for completed rental
  Future<Map<String, dynamic>> getRentalReceipt(String rentalId) async {
    return _fetchRentalDocument(
      '/rentals/$rentalId/receipt',
      fallbackFileName: 'receipt_$rentalId.pdf',
    );
  }

  // Get signed agreement for active/completed rental
  Future<Map<String, dynamic>> getSignedAgreement(String rentalId) async {
    return _fetchRentalDocument(
      '/rentals/$rentalId/signed-agreement',
      fallbackFileName: 'signed_agreement_$rentalId.pdf',
    );
  }

  // ==================== WALLET MANAGEMENT ====================

  // Get wallet balance
  Future<Map<String, dynamic>> getWalletBalance() async {
    final headers = await getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/wallet'),
      headers: headers,
    );

    return json.decode(response.body);
  }

  // Get wallet transactions
  Future<Map<String, dynamic>> getWalletTransactions({
    String? type,
    String? status,
    int perPage = 20,
  }) async {
    final headers = await getHeaders();
    final queryParams = <String, String>{};
    if (type != null) queryParams['type'] = type;
    if (status != null) queryParams['status'] = status;
    queryParams['per_page'] = perPage.toString();

    final uri = Uri.parse('$baseUrl/wallet/transactions')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);

    return json.decode(response.body);
  }

  // Get transaction details
  Future<Map<String, dynamic>> getTransactionDetails(
      String transactionId) async {
    final headers = await getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/wallet/transactions/$transactionId'),
      headers: headers,
    );

    return json.decode(response.body);
  }

  // Transfer money
  Future<Map<String, dynamic>> transferMoney({
    required String recipientPhone,
    required int amount,
    required String reason,
    String? notes,
  }) async {
    final headers = await getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/wallet/transfer'),
      headers: headers,
      body: json.encode({
        'recipient_phone': recipientPhone,
        'amount': amount,
        'reason': reason,
        if (notes != null) 'notes': notes,
      }),
    );

    return json.decode(response.body);
  }

  // Get wallet statement
  Future<Map<String, dynamic>> getWalletStatement({
    required String startDate,
    required String endDate,
    String format = 'json',
  }) async {
    final headers = await getHeaders();
    final queryParams = {
      'start_date': startDate,
      'end_date': endDate,
      'format': format,
    };

    final uri = Uri.parse('$baseUrl/wallet/statement')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);

    return json.decode(response.body);
  }

  // Initiate recharge (Cashfree)
  Future<Map<String, dynamic>> initiateRecharge({
    required int amount,
    required String paymentMethod,
  }) async {
    final headers = await getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/wallet/recharge/initiate'),
      headers: headers,
      body: json.encode({
        'amount': amount,
        'payment_method': paymentMethod,
      }),
    );

    return json.decode(response.body);
  }

  // Add these methods to your ApiService class

  Future<String?> getStoredToken() async {
    return await _storage.read(key: 'user_token');
  }

  Future<Map<String, dynamic>?> getStoredUserData() async {
    final userDataString = await _storage.read(key: 'user_data');
    if (userDataString != null) {
      return json.decode(userDataString);
    }
    return null;
  }

  // Check payment status
  Future<Map<String, dynamic>> checkPaymentStatus(String orderId) async {
    final headers = await getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/wallet/payment-status?order_id=$orderId'),
      headers: headers,
    );

    return json.decode(response.body);
  }

  // ==================== REPORTS MANAGEMENT ====================

  // Get reports summary
  Future<Map<String, dynamic>> getReportsSummary() async {
    final headers = await getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/reports/summary'),
      headers: headers,
    );
    return json.decode(response.body);
  }

  // Get earnings report
  Future<Map<String, dynamic>> getReportsEarnings({
    String? startDate,
    String? endDate,
    String? month,
    String? year,
  }) async {
    final headers = await getHeaders();
    final queryParams = <String, String>{};
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;
    if (month != null) queryParams['month'] = month;
    if (year != null) queryParams['year'] = year;

    final uri = Uri.parse('$baseUrl/reports/earnings')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    return json.decode(response.body);
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
  }) async {
    final headers = await getHeaders();
    final queryParams = <String, String>{};
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;
    if (date != null) queryParams['date'] = date;
    if (status != null) queryParams['status'] = status;
    if (vehicleId != null) queryParams['vehicle_id'] = vehicleId;
    if (customerId != null) queryParams['customer_id'] = customerId;
    if (sortBy != null) queryParams['sort_by'] = sortBy;
    if (sortOrder != null) queryParams['sort_order'] = sortOrder;
    queryParams['per_page'] = perPage.toString();

    final uri = Uri.parse('$baseUrl/reports/rentals')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    return json.decode(response.body);
  }

  // Get top vehicles report
  Future<Map<String, dynamic>> getReportsTopVehicles({
    int limit = 10,
    String? period,
  }) async {
    final headers = await getHeaders();
    final queryParams = <String, String>{};
    queryParams['limit'] = limit.toString();
    if (period != null) queryParams['period'] = period;

    final uri = Uri.parse('$baseUrl/reports/top-vehicles')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    return json.decode(response.body);
  }

  // Get top customers report
  Future<Map<String, dynamic>> getReportsTopCustomers({
    int limit = 10,
  }) async {
    final headers = await getHeaders();
    final queryParams = <String, String>{};
    queryParams['limit'] = limit.toString();

    final uri = Uri.parse('$baseUrl/reports/top-customers')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    return json.decode(response.body);
  }

  // Get documents report
  Future<Map<String, dynamic>> getReportsDocuments() async {
    final headers = await getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/reports/documents'),
      headers: headers,
    );
    return json.decode(response.body);
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
    final headers = await getHeaders();
    final queryParams = <String, String>{};
    if (startDate != null) queryParams['start_date'] = startDate;
    if (endDate != null) queryParams['end_date'] = endDate;
    if (date != null) queryParams['date'] = date;
    if (status != null) queryParams['status'] = status;
    if (vehicleId != null) queryParams['vehicle_id'] = vehicleId;
    if (customerId != null) queryParams['customer_id'] = customerId;
    if (sortBy != null) queryParams['sort_by'] = sortBy;
    if (sortOrder != null) queryParams['sort_order'] = sortOrder;
    queryParams['format'] = format;

    final uri = Uri.parse('$baseUrl/reports/export/rentals')
        .replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: headers);
    
    // For CSV export, the response is plain text
    if (response.statusCode == 200) {
      return {
        'success': true,
        'data': response.body,
      };
    }
    
    return json.decode(response.body);
  }
}