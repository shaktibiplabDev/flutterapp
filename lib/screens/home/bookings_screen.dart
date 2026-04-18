import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'home_screen.dart';
import 'vehicles_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';
import 'rental_detail_screen.dart';
import 'notifications_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  static const String _serverOrigin = 'https://rentos.versaero.top';
  static const String _storageBaseUrl = '$_serverOrigin/storage/';

  bool _isLoading = true;
  bool _isLoadingWallet = true;
  List<Map<String, dynamic>> _bookings = [];
  String _selectedFilter = 'all';
  String _searchQuery = '';
  int _selectedIndex = 2;
  int _walletBalance = 0;
  bool _isProcessing = false;
  Timer? _liveTicker;
  DateTime _now = DateTime.now();
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUnreadNotificationCount();
    _startLiveTicker();
  }

  @override
  void dispose() {
    _liveTicker?.cancel();
    super.dispose();
  }

  void _startLiveTicker() {
    _liveTicker?.cancel();
    _liveTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final apiService = ApiService();
      final response = await apiService.getUnreadNotificationsCount();
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _unreadNotificationCount = response['data']['unread_count'] ?? 0;
        });
      }
    } catch (e) {
      print('Error loading unread notification count: $e');
    }
  }

  Future<void> _navigateToNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
    
    // Refresh unread count when coming back from notifications screen
    await _loadUnreadNotificationCount();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadBookings(),
      _loadWalletBalance(),
    ]);
  }

  Future<void> _loadBookings() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final results = await Future.wait([
        authProvider.getActiveRentals(),
        authProvider.getRentalHistory(perPage: 100),
      ]);

      final activeResponse = results[0];
      final historyResponse = results[1];

      final allBookings = <Map<String, dynamic>>[
        ..._extractBookingList(activeResponse['data']),
        ..._extractBookingList(historyResponse['data']),
      ];

      final deduped = <String, Map<String, dynamic>>{};
      for (final booking in allBookings) {
        final id = _stringValue(booking['id']);
        if (id.isNotEmpty) {
          deduped[id] = booking;
        } else {
          deduped['local_${deduped.length}'] = booking;
        }
      }

      if (!mounted) return;
      setState(() {
        _bookings = deduped.values.toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading bookings: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _extractBookingList(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (data is Map) {
      for (final key in const ['rentals', 'data', 'items']) {
        final value = data[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }
    }

    return const [];
  }

  Future<void> _loadWalletBalance() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final balance = await authProvider.getWalletBalance();
      setState(() {
        _walletBalance = balance;
        _isLoadingWallet = false;
      });
    } catch (e) {
      print('Error loading wallet: $e');
      setState(() {
        _isLoadingWallet = false;
      });
    }
  }

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        
        if (!mounted) return;
        
        final result = await OpenFile.open(file.path);
        
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please install a PDF viewer app to view the document'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download file'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to download file'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveAndOpenFileBytes(List<int> bytes, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (!mounted) return;

      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please install a PDF viewer app to view the document'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save document'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showReturnDialog(Map<String, dynamic> booking) async {
    bool vehicleInGoodCondition = true;
    int damageAmount = 0;
    final damageAmountController = TextEditingController();
    final damageDescriptionController = TextEditingController();
    List<File> damageImages = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Return Vehicle',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildRadioOption(
                                label: 'Good Condition',
                                value: true,
                                groupValue: vehicleInGoodCondition,
                                onChanged: (value) {
                                  setState(() {
                                    vehicleInGoodCondition = value!;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildRadioOption(
                                label: 'Damaged',
                                value: false,
                                groupValue: vehicleInGoodCondition,
                                onChanged: (value) {
                                  setState(() {
                                    vehicleInGoodCondition = value!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        if (!vehicleInGoodCondition) ...[
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: damageDescriptionController,
                            label: 'Damage Description',
                            hint: 'Describe the damage',
                            icon: Icons.description_outlined,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: damageAmountController,
                            label: 'Damage Amount (₹)',
                            hint: 'Enter damage amount',
                            icon: Icons.currency_rupee,
                            keyboardType: TextInputType.number,
                            onChanged: (value) {
                              damageAmount = int.tryParse(value) ?? 0;
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildDamageImagePicker(
                            label: 'Damage Images',
                            imageFiles: damageImages,
                            onTap: () async {
                              final picker = ImagePicker();
                              final pickedFiles = await picker.pickMultiImage();
                              if (pickedFiles.isNotEmpty) {
                                setState(() {
                                  damageImages = pickedFiles
                                      .map((image) => File(image.path))
                                      .toList();
                                });
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _processReturn(
                            booking['id'].toString(),
                            vehicleInGoodCondition,
                            damageAmount,
                            damageDescriptionController.text,
                            damageImages,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Confirm Return',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRadioOption({
    required String label,
    required bool value,
    required bool groupValue,
    required Function(bool?) onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: groupValue == value ? Colors.black : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: groupValue == value ? Colors.black : Colors.grey.shade300,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: groupValue == value ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              prefixIcon: Icon(icon, color: Colors.grey, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDamageImagePicker({
    required String label,
    required List<File> imageFiles,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: imageFiles.isEmpty
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 32, color: Colors.grey.shade500),
                      const SizedBox(height: 8),
                      Text('Tap to upload', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${imageFiles.length} image(s) selected',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 72,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: imageFiles.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, index) => ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              imageFiles[index],
                              fit: BoxFit.cover,
                              width: 72,
                              height: 72,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _processReturn(
    String rentalId,
    bool vehicleInGoodCondition,
    int damageAmount,
    String damageDescription,
    List<File> damageImages,
  ) async {
    setState(() {
      _isProcessing = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final response = await authProvider.returnVehicle(
        rentalId: int.parse(rentalId),
        vehicleInGoodCondition: vehicleInGoodCondition,
        damageAmount: vehicleInGoodCondition ? null : damageAmount,
        damageDescription: vehicleInGoodCondition ? null : damageDescription,
        damageImages: vehicleInGoodCondition ? null : damageImages,
      );
      
      if (response['success'] == true) {
        final data = response['data'];
        final charges = data['charges'];
        final totalAmount = charges['total']['formatted'];
        
        _showReturnSummaryDialog(
          rentalId: rentalId,
          totalAmount: totalAmount,
          vehicleInGoodCondition: vehicleInGoodCondition,
        );
        await _loadBookings();
        await authProvider.fetchWalletBalance();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to return vehicle'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showReturnSummaryDialog({
    required String rentalId,
    required String totalAmount,
    required bool vehicleInGoodCondition,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              vehicleInGoodCondition ? Icons.check_circle : Icons.warning_amber_rounded,
              color: vehicleInGoodCondition ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 10),
            const Text('Return Summary'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vehicle returned successfully!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount:'),
                      Text(
                        totalAmount,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Receipt has been generated. You can download it from the booking details.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadReceipt(rentalId);
            },
            child: const Text('Download Receipt'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCancelDialog(Map<String, dynamic> booking) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Cancel Rental'),
        content: Text(
          'Are you sure you want to cancel this rental? Verification fee (₹5) is non-refundable.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cancelRental(booking['id'].toString());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelRental(String rentalId) async {
    setState(() {
      _isProcessing = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final response = await authProvider.cancelRental(rentalId);
      
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rental cancelled successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadBookings();
        await authProvider.fetchWalletBalance();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to cancel rental'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _downloadReceiptFromBooking(Map<String, dynamic> booking) async {
    final rentalId = _stringValue(booking['id']);
    final directReceipt = _stringValue(booking['receipt_path']);
    if (directReceipt.isNotEmpty) {
      await _downloadFile(
        _resolveMediaUrl(directReceipt),
        'receipt_$rentalId.pdf',
      );
      return;
    }
    await _downloadReceipt(rentalId);
  }

  Future<void> _downloadAgreementFromBooking(Map<String, dynamic> booking) async {
    final rentalId = _stringValue(booking['id']);
    final directAgreement = _stringValue(
      booking['signed_agreement_path'] ?? booking['agreement_path'],
    );
    if (directAgreement.isNotEmpty) {
      final extension = directAgreement.toLowerCase().endsWith('.pdf')
          ? 'pdf'
          : directAgreement.toLowerCase().endsWith('.png')
              ? 'png'
              : 'jpg';
      await _downloadFile(
        _resolveMediaUrl(directAgreement),
        'signed_agreement_$rentalId.$extension',
      );
      return;
    }
    await _downloadSignedAgreement(rentalId);
  }

  Future<void> _downloadReceipt(String rentalId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final response = await authProvider.getRentalReceipt(rentalId);
    final receiptPath = _extractDownloadUrl(response, preferredKeys: const [
      'receipt_path',
      'receipt_url',
      'url',
      'file_url',
      'download_url',
    ]);

    if (receiptPath != null) {
      await _downloadFile(receiptPath, 'receipt_$rentalId.pdf');
      return;
    }

    final bytes = _extractDocumentBytes(response);
    if (bytes != null && bytes.isNotEmpty) {
      await _saveAndOpenFileBytes(bytes, 'receipt_$rentalId.pdf');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response['message'] ?? 'Receipt not available'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _downloadSignedAgreement(String rentalId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final response = await authProvider.getSignedAgreement(rentalId);
    final agreementPath = _extractDownloadUrl(response, preferredKeys: const [
      'signed_agreement_path',
      'signed_agreement_url',
      'agreement_path',
      'agreement_url',
      'url',
      'file_url',
      'download_url',
    ]);

    if (agreementPath != null) {
      await _downloadFile(agreementPath, 'signed_agreement_$rentalId.pdf');
      return;
    }

    final bytes = _extractDocumentBytes(response);
    if (bytes != null && bytes.isNotEmpty) {
      await _saveAndOpenFileBytes(bytes, 'signed_agreement_$rentalId.pdf');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(response['message'] ?? 'Signed agreement not available yet'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _extractDownloadUrl(
    Map<String, dynamic> response, {
    required List<String> preferredKeys,
  }) {
    final data = response['data'];

    if (data is String && data.trim().isNotEmpty) {
      return _resolveMediaUrl(data);
    }

    if (data is Map) {
      for (final key in preferredKeys) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) {
          return _resolveMediaUrl(value);
        }
      }
    }

    for (final key in preferredKeys) {
      final value = response[key];
      if (value is String && value.trim().isNotEmpty) {
        return _resolveMediaUrl(value);
      }
    }

    return null;
  }

  List<int>? _extractDocumentBytes(Map<String, dynamic> response) {
    dynamic getValue(Map<String, dynamic> source, List<String> keys) {
      for (final key in keys) {
        if (source.containsKey(key) && source[key] != null) {
          return source[key];
        }
      }
      return null;
    }

    final data = response['data'];
    final top = response;
    final scoped = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

    final directBytes = getValue(scoped, const ['bytes']);
    if (directBytes is List) {
      return directBytes.map((e) => e as int).toList();
    }

    final directTopBytes = getValue(top, const ['bytes']);
    if (directTopBytes is List) {
      return directTopBytes.map((e) => e as int).toList();
    }

    final base64Value = getValue(scoped, const [
          'bytes_base64',
          'file_base64',
          'base64',
          'document_base64',
        ]) ??
        getValue(top, const [
          'bytes_base64',
          'file_base64',
          'base64',
          'document_base64',
        ]);
    if (base64Value is String && base64Value.trim().isNotEmpty) {
      try {
        return base64Decode(base64Value.trim());
      } catch (_) {}
    }

    final hexValue = getValue(scoped, const ['hex', 'file_hex', 'document_hex']) ??
        getValue(top, const ['hex', 'file_hex', 'document_hex']);
    if (hexValue is String && hexValue.trim().isNotEmpty) {
      final decoded = _tryDecodeHex(hexValue.trim());
      if (decoded != null) return decoded;
    }

    return null;
  }

  List<int>? _tryDecodeHex(String value) {
    final normalized = value
        .replaceAll(RegExp(r'\s+'), '')
        .replaceFirst(RegExp(r'^0x', caseSensitive: false), '')
        .replaceAll('"', '');
    if (normalized.isEmpty || normalized.length.isOdd) return null;
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(normalized)) return null;

    final out = <int>[];
    for (int i = 0; i < normalized.length; i += 2) {
      out.add(int.parse(normalized.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  List<Map<String, dynamic>> get _filteredBookings {
    List<Map<String, dynamic>> filtered = _bookings;

    if (_selectedFilter != 'all') {
      filtered = filtered.where((booking) {
        final status = _normalizedStatus(booking['status']);
        if (_selectedFilter == 'active') return _isActiveStatus(status);
        if (_selectedFilter == 'completed') return status == 'completed';
        if (_selectedFilter == 'cancelled') return status == 'cancelled';
        if (_selectedFilter == 'pending') return status == 'pending';
        return true;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((booking) {
        final customer = _asMap(booking['customer']);
        final vehicle = _asMap(booking['vehicle']);
        final customerName = _stringValue(
          booking['customer_name'] ?? customer?['name'],
        ).toLowerCase();
        final vehicleName = _stringValue(
          booking['vehicle_name'] ?? vehicle?['name'],
        ).toLowerCase();
        final query = _searchQuery.toLowerCase();
        return customerName.contains(query) || vehicleName.contains(query);
      }).toList();
    }

    filtered.sort((a, b) {
      final dateA = DateTime.tryParse(a['created_at'] ?? '');
      final dateB = DateTime.tryParse(b['created_at'] ?? '');
      return dateB?.compareTo(dateA ?? DateTime.now()) ?? 0;
    });

    return filtered;
  }

  Color _getStatusColor(String? status) {
    switch (_normalizedStatus(status)) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (_normalizedStatus(status)) {
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'pending':
        return 'Pending';
      default:
        return status ?? 'Unknown';
    }
  }

  String _normalizedStatus(dynamic status) {
    final value = _stringValue(status).toLowerCase();
    if (value == 'in_progress' || value == 'ongoing') return 'active';
    if (value == 'canceled') return 'cancelled';
    return value;
  }

  bool _isActiveStatus(String status) {
    return status == 'active';
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatWalletAmount(int amount) {
    if (amount >= 10000000) return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}k';
    return amount.toString();
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String _stringValue(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  double _doubleValue(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  String _customerName(Map<String, dynamic> booking) {
    final customer = _asMap(booking['customer']);
    return _stringValue(
      booking['customer_name'] ?? customer?['name'],
      fallback: 'Customer',
    );
  }

  String _customerPhone(Map<String, dynamic> booking) {
    final customer = _asMap(booking['customer']);
    return _stringValue(customer?['phone'], fallback: 'N/A');
  }

  String _vehicleName(Map<String, dynamic> booking) {
    final vehicle = _asMap(booking['vehicle']);
    return _stringValue(
      booking['vehicle_name'] ?? vehicle?['name'],
      fallback: 'Vehicle',
    );
  }

  String _vehicleNumberPlate(Map<String, dynamic> booking) {
    final vehicle = _asMap(booking['vehicle']);
    return _stringValue(vehicle?['number_plate'], fallback: 'N/A');
  }

  String? _bookingCustomerImage(Map<String, dynamic> booking) {
    final customer = _asMap(booking['customer']);
    final imagePath = _stringValue(
      customer?['customer_photo_url'] ??
          customer?['license_photo'] ??
          customer?['photo'],
    );
    if (imagePath.isEmpty) return null;
    return _resolveMediaUrl(imagePath);
  }

  String _bookingStartDate(Map<String, dynamic> booking) {
    return _formatDate(
      booking['start_date']?.toString() ?? booking['start_time']?.toString(),
    );
  }

  String _bookingEndDate(Map<String, dynamic> booking) {
    return _formatDate(
      booking['end_date']?.toString() ?? booking['end_time']?.toString(),
    );
  }

  String _bookingTotalAmountText(Map<String, dynamic> booking) {
    final total = booking['total_amount'] ?? booking['total_price'];
    final amount = _doubleValue(total);
    return amount == 0 ? '₹0' : '₹${amount.toStringAsFixed(2)}';
  }

  String _resolveMediaUrl(String pathOrUrl) {
    final value = pathOrUrl.trim();
    if (value.isEmpty) return value;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/storage/')) return '$_serverOrigin$value';
    if (value.startsWith('storage/')) return '$_serverOrigin/$value';
    return '$_storageBaseUrl$value';
  }

  Duration? _activeElapsed(Map<String, dynamic> booking) {
    final startValue = booking['start_time'] ?? booking['start_date'];
    final start = DateTime.tryParse(_stringValue(startValue));
    if (start == null) return null;
    final utcNow = _now.toUtc();
    final diff = utcNow.difference(start.toUtc());
    if (diff.isNegative) return Duration.zero;
    return diff;
  }

  String _formatElapsed(Duration? duration) {
    if (duration == null) return 'N/A';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _activeEstimatedAmount(Map<String, dynamic> booking) {
    final elapsed = _activeElapsed(booking);
    if (elapsed == null) return '₹0';
    final vehicle = _asMap(booking['vehicle']);
    final hourlyRate = _doubleValue(
      booking['hourly_rate'] ?? vehicle?['hourly_rate'],
      fallback: 0,
    );
    if (hourlyRate <= 0) return '₹0';
    final minutes = elapsed.inMinutes <= 0 ? 1 : elapsed.inMinutes;
    final hoursCharged = (minutes / 60).ceil();
    final amount = hourlyRate * hoursCharged;
    return '₹${amount.toStringAsFixed(2)}';
  }

  String _durationText(Map<String, dynamic> booking, {required bool isActive}) {
    if (isActive) {
      return _formatElapsed(_activeElapsed(booking));
    }
    final durationDays = booking['duration_days'];
    if (durationDays != null) {
      return '${durationDays.toString()} days';
    }
    final start = DateTime.tryParse(_stringValue(booking['start_time']));
    final end = DateTime.tryParse(_stringValue(booking['end_time']));
    if (start != null && end != null) {
      final duration = end.difference(start);
      final days = duration.inDays;
      if (days > 0) return '$days day(s)';
      final hours = duration.inHours;
      if (hours > 0) return '$hours hour(s)';
      return '${duration.inMinutes} min';
    }
    return 'N/A';
  }

  void _navigateToRentalDetail(Map<String, dynamic> booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RentalDetailScreen(rental: booking),
      ),
    ).then((_) => _loadBookings());
  }

  void _onNavBarTap(int index) {
    if (index == _selectedIndex) return;

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const VehiclesScreen()),
      );
    } else if (index == 2) {
      // Already on bookings
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isLoadingWallet || _isProcessing) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leadingWidth: 120,
          title: const Text(
            'Bookings',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.grey.shade900,
          elevation: 0,
          leading: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WalletScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '₹${_formatWalletAmount(_walletBalance)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade900,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.notifications_none, color: Colors.grey.shade700),
                  if (_unreadNotificationCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: _navigateToNotifications,
            ),
          ],
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.grey),
        ),
      );
    }

    // Calculate counts
    int totalCount = _bookings.length;
    int activeCount = _bookings.where((b) => _isActiveStatus(_normalizedStatus(b['status']))).length;
    int completedCount = _bookings.where((b) => _normalizedStatus(b['status']) == 'completed').length;
    int cancelledCount = _bookings.where((b) => _normalizedStatus(b['status']) == 'cancelled').length;
    int pendingCount = _bookings.where((b) => _normalizedStatus(b['status']) == 'pending').length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leadingWidth: 120,
        title: const Text(
          'Bookings',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey.shade900,
        elevation: 0,
        leading: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const WalletScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 18,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '₹${_formatWalletAmount(_walletBalance)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade900,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.notifications_none, color: Colors.grey.shade700),
                if (_unreadNotificationCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _navigateToNotifications,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by customer or vehicle...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey.shade500),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ),

          // Filter Chips with counts
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: Text('All ($totalCount)',
                        style: TextStyle(
                          color: _selectedFilter == 'all'
                              ? Colors.white
                              : Colors.grey.shade700,
                        )),
                    selected: _selectedFilter == 'all',
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = 'all';
                      });
                    },
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: Colors.black,
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text('Active ($activeCount)',
                        style: TextStyle(
                          color: _selectedFilter == 'active'
                              ? Colors.white
                              : Colors.grey.shade700,
                        )),
                    selected: _selectedFilter == 'active',
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = 'active';
                      });
                    },
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text('Pending ($pendingCount)',
                        style: TextStyle(
                          color: _selectedFilter == 'pending'
                              ? Colors.white
                              : Colors.grey.shade700,
                        )),
                    selected: _selectedFilter == 'pending',
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = 'pending';
                      });
                    },
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text('Completed ($completedCount)',
                        style: TextStyle(
                          color: _selectedFilter == 'completed'
                              ? Colors.white
                              : Colors.grey.shade700,
                        )),
                    selected: _selectedFilter == 'completed',
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = 'completed';
                      });
                    },
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text('Cancelled ($cancelledCount)',
                        style: TextStyle(
                          color: _selectedFilter == 'cancelled'
                              ? Colors.white
                              : Colors.grey.shade700,
                        )),
                    selected: _selectedFilter == 'cancelled',
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = 'cancelled';
                      });
                    },
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: Colors.red,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Bookings List
          Expanded(
            child: _filteredBookings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No bookings found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadBookings,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredBookings.length,
                      itemBuilder: (context, index) {
                        final booking = _filteredBookings[index];
                        final statusColor = _getStatusColor(booking['status']);
                        final normalizedStatus = _normalizedStatus(
                          booking['status'],
                        );
                        final isActive = _isActiveStatus(normalizedStatus);
                        final isCompleted = normalizedStatus == 'completed';
                        final isPending = normalizedStatus == 'pending';

                        return GestureDetector(
                          onTap: () => _navigateToRentalDetail(booking),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: _bookingCustomerImage(booking) !=
                                                    null
                                                ? ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(10),
                                                    child: Image.network(
                                                      _bookingCustomerImage(booking)!,
                                                      fit: BoxFit.cover,
                                                      errorBuilder:
                                                          (_, __, ___) => Icon(
                                                        Icons.person_outline,
                                                        size: 28,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  )
                                                : Icon(
                                                    Icons.person_outline,
                                                    size: 28,
                                                    color: Colors.grey.shade600,
                                                  ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _customerName(booking),
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey.shade900,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _vehicleName(booking),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  statusColor.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              _getStatusText(booking['status']),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: statusColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.calendar_today_outlined,
                                                  size: 14,
                                                  color: Colors.grey.shade500,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Start: ${_bookingStartDate(booking)}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.calendar_today_outlined,
                                                  size: 14,
                                                  color: Colors.grey.shade500,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'End: ${_bookingEndDate(booking)}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 14,
                                                  color: Colors.grey.shade500,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _durationText(
                                                    booking,
                                                    isActive: isActive,
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.currency_rupee,
                                                  size: 14,
                                                  color: Colors.grey.shade500,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  isActive
                                                      ? _activeEstimatedAmount(
                                                          booking,
                                                        )
                                                      : _bookingTotalAmountText(
                                                          booking,
                                                        ),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey.shade900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.phone_outlined,
                                                  size: 14,
                                                  color: Colors.grey.shade500,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    _customerPhone(booking),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey.shade500,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.badge_outlined,
                                                  size: 14,
                                                  color: Colors.grey.shade500,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    _vehicleNumberPlate(booking),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey.shade500,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (isActive) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.08),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Colors.green.withOpacity(0.25),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.timelapse,
                                                size: 15,
                                                color: Colors.green.shade700,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Live: ${_formatElapsed(_activeElapsed(booking))}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.green.shade700,
                                                ),
                                              ),
                                              const Spacer(),
                                              Text(
                                                'Est. ${_activeEstimatedAmount(booking)}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.green.shade800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (isPending) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.08),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Colors.orange.withOpacity(0.25),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.hourglass_empty,
                                                size: 15,
                                                color: Colors.orange.shade700,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Awaiting confirmation',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.orange.shade700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                // Action Buttons for Active Rentals
                                if (isActive)
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () {
                                                  _downloadAgreementFromBooking(
                                                    booking,
                                                  );
                                                },
                                                style: OutlinedButton.styleFrom(
                                                  side: BorderSide(
                                                    color: Colors.grey.shade300,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                ),
                                                icon: const Icon(
                                                  Icons.description_outlined,
                                                  size: 16,
                                                ),
                                                label: const Text('Agreement'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () {
                                                  _showCancelDialog(booking);
                                                },
                                                style: OutlinedButton.styleFrom(
                                                  side: BorderSide(
                                                    color: Colors.red.shade400,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                  foregroundColor:
                                                      Colors.red.shade400,
                                                ),
                                                icon: const Icon(
                                                  Icons.close_rounded,
                                                  size: 16,
                                                ),
                                                label: const Text('Cancel'),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              _showReturnDialog(booking);
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.black,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            icon: const Icon(
                                              Icons.assignment_turned_in_outlined,
                                              size: 16,
                                            ),
                                            label: const Text('Return Vehicle'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Action Buttons for Completed Rentals
                                if (isCompleted)
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () {
                                              _downloadAgreementFromBooking(booking);
                                            },
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                  color: Colors.grey.shade300),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            icon: const Icon(Icons.description_outlined, size: 16),
                                            label: const Text('Agreement'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () {
                                              _downloadReceiptFromBooking(booking);
                                            },
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                  color: Colors.grey.shade300),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            icon: const Icon(Icons.receipt_long_outlined, size: 16),
                                            label: const Text('Receipt'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Action Buttons for Pending Rentals
                                if (isPending)
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () {
                                              _showCancelDialog(booking);
                                            },
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(
                                                  color: Colors.red.shade400),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              foregroundColor: Colors.red.shade400,
                                            ),
                                            icon: const Icon(
                                              Icons.close_rounded,
                                              size: 16,
                                            ),
                                            label: const Text('Cancel'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey.shade500,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_outlined),
            activeIcon: Icon(Icons.directions_car),
            label: 'Vehicles',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onNavBarTap,
      ),
    );
  }
}