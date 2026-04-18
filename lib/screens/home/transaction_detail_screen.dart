import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'home_screen.dart';
import 'vehicles_screen.dart';
import 'bookings_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> transaction;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> with SingleTickerProviderStateMixin {
  Map<String, dynamic> _transactionDetails = {};
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
    _loadTransactionDetails();
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

  Future<void> _loadTransactionDetails() async {
    setState(() => _isLoading = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final transactionId = widget.transaction['id'].toString();

    try {
      final response = await authProvider.getTransactionDetails(transactionId);
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _transactionDetails = response['data'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _transactionDetails = widget.transaction;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _transactionDetails = widget.transaction;
        _isLoading = false;
      });
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

  void _copyToClipboard(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.grey.shade800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'Transaction Details',
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

    final isCredit = _transactionDetails['type'] == 'credit';
    final amount = _transactionDetails['amount'] ?? 0;
    final formattedAmount = _transactionDetails['formatted_amount'] ?? '₹$amount';
    final status = _transactionDetails['status'] ?? 'pending';
    final statusColor = status == 'completed' 
        ? Colors.green 
        : status == 'pending' 
            ? Colors.orange 
            : Colors.red;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Transaction Details',
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
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadTransactionDetails();
          await _loadUnreadNotificationCount();
        },
        color: Colors.black,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Amount Card Sliver
            SliverToBoxAdapter(
              child: FadeInAnimation(
                delay: 0,
                controller: _animationController,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade100,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: (isCredit ? Colors.green : Colors.red).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                          size: 35,
                          color: isCredit ? Colors.green : Colors.red,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isCredit ? 'Amount Credited' : 'Amount Debited',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        formattedAmount,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: isCredit ? Colors.green : Colors.red,
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
                              status == 'completed' ? Icons.check_circle : status == 'pending' ? Icons.pending : Icons.error_outline,
                              size: 14,
                              color: statusColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _transactionDetails['status_label'] ?? status.toUpperCase(),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Transaction Details Section Sliver
            SliverToBoxAdapter(
              child: FadeInAnimation(
                delay: 0.1,
                controller: _animationController,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade100,
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transaction Details',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Transaction ID', _transactionDetails['reference_id'] ?? 'N/A', isCopyable: true),
                      const Divider(height: 24),
                      _buildInfoRow('Type', _transactionDetails['type_label'] ?? (isCredit ? 'Credit' : 'Debit')),
                      const Divider(height: 24),
                      _buildInfoRow('Amount', formattedAmount),
                      const Divider(height: 24),
                      _buildInfoRow('Reason', _transactionDetails['reason'] ?? 'N/A'),
                      const Divider(height: 24),
                      _buildInfoRow('Status', _transactionDetails['status_label'] ?? status.toUpperCase()),
                      if (_transactionDetails['payment_method'] != null && _transactionDetails['payment_method'].toString().isNotEmpty)
                        Column(
                          children: [
                            const Divider(height: 24),
                            _buildInfoRow('Payment Method', _transactionDetails['payment_method'].toString().toUpperCase()),
                          ],
                        ),
                      if (_transactionDetails['notes'] != null && _transactionDetails['notes'].toString().isNotEmpty)
                        Column(
                          children: [
                            const Divider(height: 24),
                            _buildInfoRow('Notes', _transactionDetails['notes']),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Date & Time Section Sliver
            SliverToBoxAdapter(
              child: FadeInAnimation(
                delay: 0.2,
                controller: _animationController,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade100,
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date & Time',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow('Created At', _transactionDetails['created_at_formatted'] ?? 'N/A'),
                      if (_transactionDetails['updated_at'] != null && 
                          _transactionDetails['created_at'] != _transactionDetails['updated_at'])
                        Column(
                          children: [
                            const Divider(height: 24),
                            _buildInfoRow('Last Updated', _transactionDetails['updated_at_formatted'] ?? 'N/A'),
                          ],
                        ),
                      if (_transactionDetails['created_at_human'] != null)
                        Column(
                          children: [
                            const Divider(height: 24),
                            _buildInfoRow('Time Elapsed', _transactionDetails['created_at_human']),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
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
        currentIndex: 0,
        onTap: _onNavBarTap,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isCopyable = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
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
                    color: Colors.grey.shade900,
                  ),
                ),
              ),
              if (isCopyable && value != 'N/A')
                IconButton(
                  icon: Icon(Icons.copy, size: 16, color: Colors.grey.shade500),
                  onPressed: () => _copyToClipboard(value),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ],
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