import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'home_screen.dart';
import 'vehicles_screen.dart';
import 'bookings_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';

class RentalDetailScreen extends StatefulWidget {
  final Map<String, dynamic> rental;

  const RentalDetailScreen({
    super.key,
    required this.rental,
  });

  @override
  State<RentalDetailScreen> createState() => _RentalDetailScreenState();
}

class _RentalDetailScreenState extends State<RentalDetailScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic> _rentalDetails = {};
  bool _isLoading = true;
  late AnimationController _animationController;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadRentalDetails();
    _loadUnreadNotificationCount();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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

  Future<void> _loadRentalDetails() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final rentalId = widget.rental['id'].toString();

    try {
      final response = await authProvider.getRentalDetails(rentalId);
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _rentalDetails = response['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _rentalDetails = widget.rental;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _rentalDetails = widget.rental;
        _isLoading = false;
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
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download file: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onNavBarTap(int index) {
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
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const BookingsScreen()),
      );
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatCurrency(String? amount) {
    if (amount == null) return '₹0';
    final value = double.tryParse(amount) ?? 0;
    return '₹${value.toStringAsFixed(2)}';
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'in_progress':
      case 'ongoing':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
      case 'canceled':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
      case 'in_progress':
      case 'ongoing':
        return 'Active';
      case 'completed':
        return 'Completed';
      case 'cancelled':
      case 'canceled':
        return 'Cancelled';
      case 'pending':
        return 'Pending';
      default:
        return status ?? 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Rental Details',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: -0.5),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.grey.shade900,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.grey.shade900),
            onPressed: () => Navigator.pop(context),
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
        body: const Center(child: CircularProgressIndicator(color: Colors.grey)),
      );
    }

    final vehicle = _rentalDetails['vehicle'] ?? {};
    final customer = _rentalDetails['customer'] ?? {};
    final status = _rentalDetails['status'] ?? 'pending';
    final statusColor = _getStatusColor(status);
    final isActive = status == 'active' || status == 'in_progress' || status == 'ongoing';
    final isCompleted = status == 'completed';
    final isPending = status == 'pending';

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Rental Details',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey.shade900,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey.shade900),
          onPressed: () => Navigator.pop(context),
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Status Card
            FadeInAnimation(
              delay: 0,
              controller: _animationController,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.shade100, blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isActive ? Icons.play_circle_outline : 
                        isCompleted ? Icons.check_circle_outline :
                        isPending ? Icons.pending_outlined :
                        Icons.cancel_outlined,
                        size: 35,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Rental Status',
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getStatusText(status),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: statusColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Phase: ${_rentalDetails['phase'] ?? 'N/A'}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Rental Info Section
            FadeInAnimation(
              delay: 0.1,
              controller: _animationController,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rental Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Rental ID', '#${_rentalDetails['id'] ?? 'N/A'}', isCopyable: true),
                    const Divider(height: 24),
                    _buildInfoRow('Total Price', _formatCurrency(_rentalDetails['total_price'])),
                    const Divider(height: 24),
                    _buildInfoRow('Verification Fee', _formatCurrency(_rentalDetails['verification_fee_deducted'])),
                    if (_rentalDetails['is_verification_cached'] == '1')
                      Column(
                        children: [
                          const Divider(height: 24),
                          _buildInfoRow('Verification', 'Cached (₹5 saved)', valueColor: Colors.green),
                        ],
                      ),
                    const Divider(height: 24),
                    _buildInfoRow('Created', _formatDate(_rentalDetails['created_at'])),
                  ],
                ),
              ),
            ),

            // Vehicle Section
            FadeInAnimation(
              delay: 0.2,
              controller: _animationController,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            vehicle['type'] == 'SUV' || vehicle['type'] == 'car'
                                ? Icons.directions_car
                                : Icons.motorcycle,
                            size: 32,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vehicle['name'] ?? 'N/A',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                              ),
                              Text(
                                vehicle['number_plate'] ?? 'N/A',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Type', vehicle['type'] ?? 'N/A'),
                    const Divider(height: 24),
                    _buildInfoRow('Hourly Rate', _formatCurrency(vehicle['hourly_rate'])),
                    const Divider(height: 24),
                    _buildInfoRow('Daily Rate', _formatCurrency(vehicle['daily_rate'])),
                    const Divider(height: 24),
                    _buildInfoRow('Weekly Rate', _formatCurrency(vehicle['weekly_rate'])),
                  ],
                ),
              ),
            ),

            // Customer Section
            FadeInAnimation(
              delay: 0.3,
              controller: _animationController,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Name', customer['name'] ?? 'N/A'),
                    const Divider(height: 24),
                    _buildInfoRow('Phone', customer['phone'] ?? 'N/A', isCopyable: true),
                    const Divider(height: 24),
                    _buildInfoRow('License Number', customer['masked_license'] ?? customer['license_number'] ?? 'N/A', isCopyable: true),
                    const Divider(height: 24),
                    _buildInfoRow('Date of Birth', customer['formatted_date_of_birth'] ?? 'N/A'),
                    const Divider(height: 24),
                    _buildInfoRow('Address', customer['address'] ?? 'N/A', maxLines: 3),
                  ],
                ),
              ),
            ),

            // Timeline Section
            FadeInAnimation(
              delay: 0.4,
              controller: _animationController,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rental Timeline',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                    ),
                    const SizedBox(height: 16),
                    _buildTimelineItem(
                      title: 'Verification Completed',
                      time: _rentalDetails['verification_completed_at'],
                      icon: Icons.verified_user,
                      isCompleted: _rentalDetails['verification_completed_at'] != null,
                    ),
                    _buildTimelineItem(
                      title: 'Documents Uploaded',
                      time: _rentalDetails['document_upload_completed_at'],
                      icon: Icons.upload_file,
                      isCompleted: _rentalDetails['document_upload_completed_at'] != null,
                    ),
                    _buildTimelineItem(
                      title: 'Agreement Signed',
                      time: _rentalDetails['agreement_signed_at'],
                      icon: Icons.edit_document,
                      isCompleted: _rentalDetails['agreement_signed_at'] != null,
                    ),
                    _buildTimelineItem(
                      title: 'Vehicle Start Time',
                      time: _rentalDetails['start_time'],
                      icon: Icons.play_circle_outline,
                      isCompleted: _rentalDetails['start_time'] != null,
                    ),
                    _buildTimelineItem(
                      title: 'Vehicle Returned',
                      time: _rentalDetails['return_completed_at'],
                      icon: Icons.stop_circle_outlined,
                      isCompleted: _rentalDetails['return_completed_at'] != null,
                    ),
                  ],
                ),
              ),
            ),

            // Damage Info (if any)
            if (_rentalDetails['damage_amount'] != null && double.parse(_rentalDetails['damage_amount'].toString()) > 0)
              FadeInAnimation(
                delay: 0.5,
                controller: _animationController,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Damage Report',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Damage Amount', _formatCurrency(_rentalDetails['damage_amount'])),
                      if (_rentalDetails['damage_description'] != null && _rentalDetails['damage_description'].toString().isNotEmpty)
                        Column(
                          children: [
                            const Divider(height: 24),
                            _buildInfoRow('Description', _rentalDetails['damage_description']),
                          ],
                        ),
                      if (_rentalDetails['damage_images'] != null && (_rentalDetails['damage_images'] as List).isNotEmpty)
                        Column(
                          children: [
                            const Divider(height: 24),
                            const Text('Damage Images', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: (_rentalDetails['damage_images'] as List).length,
                                itemBuilder: (context, index) {
                                  final imageUrl = (_rentalDetails['damage_images'] as List)[index];
                                  return GestureDetector(
                                    onTap: () => _downloadFile(imageUrl, 'damage_image_${_rentalDetails['id']}_$index.jpg'),
                                    child: Container(
                                      width: 100,
                                      height: 100,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey.shade200),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: Colors.grey.shade400),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

            // Documents Section
            if (isCompleted || isActive)
              FadeInAnimation(
                delay: 0.6,
                controller: _animationController,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Documents',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                      ),
                      const SizedBox(height: 16),
                      if (_rentalDetails['receipt_path'] != null && _rentalDetails['receipt_path'].toString().isNotEmpty)
                        _buildDocumentButton(
                          title: 'Download Receipt',
                          icon: Icons.receipt_long_outlined,
                          onTap: () => _downloadFile(_rentalDetails['receipt_path'], 'receipt_${_rentalDetails['id']}.pdf'),
                        ),
                      if (_rentalDetails['signed_agreement_path'] != null && _rentalDetails['signed_agreement_path'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _buildDocumentButton(
                            title: 'Download Signed Agreement',
                            icon: Icons.description_outlined,
                            onTap: () => _downloadFile(_rentalDetails['signed_agreement_path'], 'agreement_${_rentalDetails['id']}.pdf'),
                          ),
                        ),
                      if (_rentalDetails['customer_with_vehicle_image'] != null && _rentalDetails['customer_with_vehicle_image'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _buildDocumentButton(
                            title: 'View Handover Photo',
                            icon: Icons.photo_camera_outlined,
                            onTap: () => _downloadFile(_rentalDetails['customer_with_vehicle_image'], 'handover_${_rentalDetails['id']}.jpg'),
                          ),
                        ),
                      if (_rentalDetails['vehicle_condition_video'] != null && _rentalDetails['vehicle_condition_video'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _buildDocumentButton(
                            title: 'View Condition Video',
                            icon: Icons.videocam_outlined,
                            onTap: () => _downloadFile(_rentalDetails['vehicle_condition_video'], 'condition_${_rentalDetails['id']}.mp4'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey.shade500,
        selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_car_outlined), label: 'Vehicles'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
        currentIndex: 2,
        onTap: _onNavBarTap,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isCopyable = false, Color? valueColor, int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? Colors.grey.shade900,
                  ),
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isCopyable && value != 'N/A')
                IconButton(
                  icon: Icon(Icons.copy, size: 16, color: Colors.grey.shade500),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Copied: $value'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: Colors.grey.shade800,
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required String title,
    required String? time,
    required IconData icon,
    required bool isCompleted,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green.withOpacity(0.1) : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check : icon,
              size: 16,
              color: isCompleted ? Colors.green : Colors.grey.shade400,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isCompleted ? Colors.grey.shade900 : Colors.grey.shade500,
                  ),
                ),
                if (time != null && time.isNotEmpty)
                  Text(
                    _formatDate(time),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
              ],
            ),
          ),
          if (isCompleted)
            Icon(Icons.check_circle, size: 16, color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildDocumentButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(title),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// Fade-in Animation Widget
class FadeInAnimation extends StatelessWidget {
  final Widget child;
  final double delay;
  final AnimationController controller;

  const FadeInAnimation({
    super.key,
    required this.child,
    required this.delay,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: controller,
        curve: Interval(delay, 1.0, curve: Curves.easeOut),
      ),
      child: child,
    );
  }
}