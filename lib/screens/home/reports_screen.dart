import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../providers/auth_provider.dart';
import 'home_screen.dart';
import 'vehicles_screen.dart';
import 'bookings_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  int _selectedTab = 0;
  int _selectedIndex = 0;
  
  // Data
  Map<String, dynamic> _summaryData = {};
  Map<String, dynamic> _earningsData = {};
  Map<String, dynamic> _rentalsData = {};
  Map<String, dynamic> _topVehiclesData = {};
  Map<String, dynamic> _topCustomersData = {};
  Map<String, dynamic> _documentsData = {};
  
  bool _isLoading = true;
  bool _isLoadingWallet = true;
  int _walletBalance = 0;

  final List<String> _tabs = ['Overview', 'Rentals', 'Vehicles', 'Customers', 'Documents'];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadWalletBalance();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    try {
      final results = await Future.wait([
        authProvider.getReportsSummary(),
        authProvider.getReportsEarnings(),
        authProvider.getReportsRentals(),
        authProvider.getReportsTopVehicles(),
        authProvider.getReportsTopCustomers(),
        authProvider.getReportsDocuments(),
      ]);
      
      setState(() {
        _summaryData = results[0]['data'] ?? {};
        _earningsData = results[1]['data'] ?? {};
        _rentalsData = results[2]['data'] ?? {};
        _topVehiclesData = results[3]['data'] ?? {};
        _topCustomersData = results[4]['data'] ?? {};
        _documentsData = results[5]['data'] ?? {};
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading reports: $e');
      setState(() {
        _isLoading = false;
      });
    }
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

  Future<void> _exportRentals() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final response = await authProvider.exportRentalsReport();
    
    if (response['success'] == true && response['data'] != null) {
      final csvData = response['data'];
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/rentals_report_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csvData);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report exported to ${file.path}'),
          backgroundColor: Colors.green.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to export report'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatCurrency(int amount) {
    return '₹${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},')}';
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

  String _formatWalletAmount(int amount) {
    if (amount >= 10000000) return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}k';
    return amount.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isLoadingWallet) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.grey),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _tabs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final tab = entry.value;
                  final isSelected = _selectedTab == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTab = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isSelected ? Colors.black : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        tab,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.black : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _buildOverviewTab(),
                _buildRentalsTab(),
                _buildVehiclesTab(),
                _buildCustomersTab(),
                _buildDocumentsTab(),
              ],
            ),
          ),
        ],
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
        currentIndex: _selectedIndex,
        onTap: _onNavBarTap,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Reports',
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
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WalletScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.account_balance_wallet_outlined, size: 18, color: Colors.grey.shade700),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '₹${_formatWalletAmount(_walletBalance)}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade900),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: Stack(
            children: [
              Icon(Icons.notifications_none, color: Colors.grey.shade700),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notifications coming soon'), backgroundColor: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    final currentMonth = _summaryData['current_month'] ?? {};
    final yearToDate = _summaryData['year_to_date'] ?? {};
    final growth = _summaryData['growth'] ?? {};
    final earningsData = _earningsData['summary'] ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Total Earnings',
                  value: _formatCurrency(earningsData['total_earnings'] ?? 0),
                  icon: Icons.currency_rupee,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Total Rentals',
                  value: '${earningsData['total_rentals'] ?? 0}',
                  icon: Icons.receipt_long_outlined,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Avg Rental Value',
                  value: _formatCurrency(earningsData['average_rental_value']?.toInt() ?? 0),
                  icon: Icons.trending_up,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Active Rentals',
                  value: '${currentMonth['active_rentals'] ?? 0}',
                  icon: Icons.play_circle_outlined,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Monthly Performance
          _buildSectionTitle('Monthly Performance'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _buildCardDecoration(),
            child: Column(
              children: [
                _buildComparisonRow(
                  label: 'Current Month',
                  value: _formatCurrency(currentMonth['earnings'] ?? 0),
                  period: currentMonth['period']?['month'] ?? 'April 2026',
                ),
                const Divider(height: 24),
                _buildComparisonRow(
                  label: 'Previous Month',
                  value: _formatCurrency(_summaryData['previous_month']?['earnings'] ?? 0),
                  period: _summaryData['previous_month']?['period']?['month'] ?? 'March 2026',
                ),
                const Divider(height: 24),
                _buildComparisonRow(
                  label: 'Year to Date',
                  value: _formatCurrency(yearToDate['earnings'] ?? 0),
                  period: yearToDate['period']?['year']?.toString() ?? '2026',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Growth Indicator
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _buildCardDecoration(),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (growth['trend'] == 'up' ? Colors.green : Colors.red).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    growth['trend'] == 'up' ? Icons.trending_up : Icons.trending_down,
                    color: growth['trend'] == 'up' ? Colors.green : Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Growth vs Previous Month',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${growth['earnings'] ?? 0}% Earnings Growth',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: growth['trend'] == 'up' ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Daily Earnings
          _buildSectionTitle('Daily Earnings', action: 'Export', onAction: _exportRentals),
          const SizedBox(height: 12),
          ...(_earningsData['daily_earnings'] as List? ?? []).map((day) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: _buildCardDecoration(),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.calendar_today_outlined, color: Colors.grey.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(day['date']),
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade900),
                      ),
                      Text(
                        '${day['rental_count']} rentals',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatCurrency(day['total'] ?? 0),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildRentalsTab() {
    final rentals = _rentalsData['rentals'] as List? ?? [];
    final summary = _rentalsData['summary'] ?? {};
    
    return Column(
      children: [
        // Summary Row
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Total Rentals',
                  value: '${summary['total_rentals'] ?? 0}',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Total Earnings',
                  value: _formatCurrency(summary['total_earnings'] ?? 0),
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: rentals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No rentals found', style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rentals.length,
                  itemBuilder: (context, index) {
                    final rental = rentals[index];
                    final status = rental['status'] ?? 'unknown';
                    final statusColor = status == 'completed' ? Colors.green : status == 'active' ? Colors.blue : status == 'cancelled' ? Colors.red : Colors.orange;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: _buildCardDecoration(),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  rental['vehicle']?['type'] == 'car' || rental['vehicle']?['type'] == 'SUV'
                                      ? Icons.directions_car
                                      : Icons.motorcycle,
                                  size: 28,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      rental['vehicle']?['name'] ?? 'Unknown',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                                    ),
                                    Text(
                                      rental['vehicle']?['number_plate'] ?? '',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
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
                                    Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        rental['customer']?['name'] ?? 'Customer',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatCurrency(rental['total_price'] ?? 0),
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                              ),
                            ],
                          ),
                          if (rental['start_time'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_formatDate(rental['start_time'])} → ${_formatDate(rental['end_time'])}',
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildVehiclesTab() {
    final topVehicles = _topVehiclesData['top_vehicles'] as List? ?? [];
    final summary = _topVehiclesData['summary'] ?? {};
    
    return Column(
      children: [
        // Summary Row
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Total Vehicles',
                  value: '${summary['total_vehicles'] ?? 0}',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Total Revenue',
                  value: _formatCurrency(summary['total_revenue'] ?? 0),
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: topVehicles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No vehicle data available', style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: topVehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = topVehicles[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: _buildCardDecoration(),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  vehicle['type'] == 'car' || vehicle['type'] == 'SUV'
                                      ? Icons.directions_car
                                      : Icons.motorcycle,
                                  size: 28,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vehicle['vehicle_name'] ?? 'Unknown',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                                    ),
                                    Text(
                                      vehicle['number_plate'] ?? '',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatCurrency(vehicle['total_revenue'] ?? 0),
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildVehicleStat(
                                  label: 'Rentals',
                                  value: '${vehicle['rental_count'] ?? 0}',
                                ),
                              ),
                              Expanded(
                                child: _buildVehicleStat(
                                  label: 'Completed',
                                  value: '${vehicle['completed_count'] ?? 0}',
                                ),
                              ),
                              Expanded(
                                child: _buildVehicleStat(
                                  label: 'Utilization',
                                  value: '${vehicle['utilization_rate']?.toStringAsFixed(1) ?? 0}%',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCustomersTab() {
    final topCustomers = _topCustomersData['top_customers'] as List? ?? [];
    final summary = _topCustomersData['summary'] ?? {};
    
    return Column(
      children: [
        // Summary Row
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Total Customers',
                  value: '${summary['total_customers'] ?? 0}',
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniStatCard(
                  title: 'Total Revenue',
                  value: _formatCurrency(summary['total_revenue'] ?? 0),
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: topCustomers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No customer data available', style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: topCustomers.length,
                  itemBuilder: (context, index) {
                    final customer = topCustomers[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: _buildCardDecoration(),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.person_outline, size: 28, color: Colors.grey.shade700),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      customer['customer_name'] ?? 'Customer',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                                    ),
                                    Text(
                                      customer['customer_phone'] ?? '',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatCurrency(customer['total_spent'] ?? 0),
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildCustomerStat(
                                  label: 'Rentals',
                                  value: '${customer['rental_count'] ?? 0}',
                                ),
                              ),
                              Expanded(
                                child: _buildCustomerStat(
                                  label: 'Avg Spend',
                                  value: _formatCurrency(customer['average_spent']?.toInt() ?? 0),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDocumentsTab() {
    final rentals = _documentsData['rentals'] ?? {};
    final customers = _documentsData['customers'] ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Rentals Document Stats
          _buildSectionTitle('Rental Documents'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _buildCardDecoration(),
            child: Column(
              children: [
                _buildDocumentStatRow('Total Rentals', '${rentals['total'] ?? 0}'),
                _buildDocumentStatRow('With Agreement', '${rentals['with_agreement'] ?? 0}'),
                _buildDocumentStatRow('With Receipt', '${rentals['with_receipt'] ?? 0}'),
                _buildDocumentStatRow('With Both', '${rentals['with_both'] ?? 0}'),
                _buildDocumentStatRow('Without Documents', '${rentals['without_documents'] ?? 0}'),
                const Divider(height: 24),
                _buildDocumentStatRow('Agreement Rate', '${rentals['agreement_rate'] ?? 0}%', isPercentage: true),
                _buildDocumentStatRow('Receipt Rate', '${rentals['receipt_rate'] ?? 0}%', isPercentage: true),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Customers Document Stats
          _buildSectionTitle('Customer Documents'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _buildCardDecoration(),
            child: Column(
              children: [
                _buildDocumentStatRow('Total Customers', '${customers['total'] ?? 0}'),
                _buildDocumentStatRow('With Aadhaar', '${customers['with_aadhaar'] ?? 0}'),
                _buildDocumentStatRow('With License', '${customers['with_license'] ?? 0}'),
                const Divider(height: 24),
                _buildDocumentStatRow('Aadhaar Adoption', '${customers['aadhaar_adoption_rate'] ?? 0}%', isPercentage: true),
                _buildDocumentStatRow('License Adoption', '${customers['license_adoption_rate'] ?? 0}%', isPercentage: true),
                _buildDocumentStatRow('Both Documents', '${customers['both_documents_rate'] ?? 0}%', isPercentage: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({required String title, required String value, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard({required String title, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _buildCardDecoration(),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow({required String label, required String value, required String period}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
            Text(period, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade900)),
      ],
    );
  }

  Widget _buildVehicleStat({required String label, required String value}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade900)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildCustomerStat({required String label, required String value}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade900)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildDocumentStatRow(String label, String value, {bool isPercentage = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isPercentage ? FontWeight.w600 : FontWeight.w500,
              color: isPercentage ? Colors.blue.shade700 : Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {String? action, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
          ),
          if (action != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(action, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            ),
        ],
      ),
    );
  }

  BoxDecoration _buildCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.shade100,
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}