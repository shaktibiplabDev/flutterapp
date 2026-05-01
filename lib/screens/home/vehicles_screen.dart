import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'home_screen.dart';
import 'bookings_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';
import 'add_vehicle_screen.dart';
import 'new_rental_screen.dart';
import 'notifications_screen.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  bool _isLoading = true;
  bool _isLoadingWallet = true;
  List<Map<String, dynamic>> _vehicles = [];
  String _selectedFilter = 'all';
  String _searchQuery = '';
  int _selectedIndex = 1;
  int _walletBalance = 0;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    // Use Future.microtask to avoid async execution directly in initState
    Future.microtask(() {
      _loadData();
      _loadUnreadNotificationCount();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final apiService = ApiService();
      final response = await apiService.getUnreadNotificationsCount();
      if (response['success'] == true && response['data'] != null) {
        if (mounted) {
          setState(() {
            _unreadNotificationCount = response['data']['unread_count'] ?? 0;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading unread notification count: $e');
    }
  }

  Future<void> _navigateToNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NotificationsScreen()),
    );
    await _loadUnreadNotificationCount();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadVehicles(),
      _loadWalletBalance(),
    ]);
  }

  Future<void> _loadVehicles() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      final response = await authProvider.getVehicles(perPage: 100);
      final vehiclesList = _extractVehicleList(response['data']);
      if (mounted) {
        setState(() {
          _vehicles = vehiclesList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading vehicles: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadWalletBalance() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final balance = await authProvider.getWalletBalance();
      if (mounted) {
        setState(() {
          _walletBalance = balance;
          _isLoadingWallet = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading wallet: $e');
      if (mounted) {
        setState(() {
          _isLoadingWallet = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredVehicles {
    List<Map<String, dynamic>> filtered = _vehicles;

    if (_selectedFilter != 'all') {
      filtered = filtered.where((vehicle) {
        final status = _vehicleStatus(vehicle);
        if (_selectedFilter == 'available') return status == 'available';
        if (_selectedFilter == 'on_rent') return status == 'on_rent';
        if (_selectedFilter == 'unavailable') return status == 'unavailable';
        return true;
      }).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((vehicle) {
        final name = _stringValue(vehicle['name']).toLowerCase();
        final numberPlate = _vehicleNumberPlate(vehicle).toLowerCase();
        final type = _vehicleType(vehicle).toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) ||
            numberPlate.contains(query) ||
            type.contains(query);
      }).toList();
    }

    // Safe sorting with null handling
    filtered.sort((a, b) {
      final dateAStr = _stringValue(a['created_at']);
      final dateBStr = _stringValue(b['created_at']);
      final dateA = dateAStr.isNotEmpty ? DateTime.tryParse(dateAStr) : null;
      final dateB = dateBStr.isNotEmpty ? DateTime.tryParse(dateBStr) : null;
      
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    return filtered;
  }

  List<Map<String, dynamic>> _extractVehicleList(dynamic data) {
    if (data == null) return [];
    
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (data is Map) {
      for (final key in const ['data', 'vehicles', 'items']) {
        final value = data[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }
    }
    return [];
  }

  String _stringValue(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _vehicleStatus(Map<String, dynamic> vehicle) {
    final value = _stringValue(vehicle['status']).toLowerCase();
    
    // Normalize all possible status values
    if (value == 'available') return 'available';
    if (value == 'on_rent' || value == 'onrent' || value == 'rented' || value == 'in_progress' || value == 'ongoing') {
      return 'on_rent';
    }
    if (value == 'unavailable' || value == 'maintenance') return 'unavailable';
    
    return value;
  }

  String _vehicleType(Map<String, dynamic> vehicle) {
    return _stringValue(vehicle['type'], fallback: 'vehicle');
  }

  String _vehicleNumberPlate(Map<String, dynamic> vehicle) {
    return _stringValue(
      vehicle['number_plate'] ?? vehicle['numberPlate'],
      fallback: 'No plate',
    );
  }

  String _getVehicleId(Map<String, dynamic> vehicle) {
    final id = vehicle['id'];
    if (id == null) return '';
    return id.toString();
  }

  double _getRate(Map<String, dynamic> vehicle, String rateType) {
    final value = vehicle[rateType];
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _getFormattedRate(Map<String, dynamic> vehicle, String rateType) {
    final rate = _getRate(vehicle, rateType);
    if (rate == 0) return '';
    return '₹${rate.toStringAsFixed(0)}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'available':
        return Colors.green;
      case 'on_rent':
        return Colors.orange;
      case 'unavailable':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'available':
        return 'Available';
      case 'on_rent':
        return 'On Rent';
      case 'unavailable':
        return 'Unavailable';
      default:
        return status;
    }
  }

  void _onNavBarTap(int index) {
    if (index == _selectedIndex) return;

    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
        break;
      case 1:
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BookingsScreen()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
        break;
    }
  }

  String _formatWalletAmount(int amount) {
    if (amount >= 10000000) {
      return '${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}k';
    } else {
      return amount.toString();
    }
  }

  void _showEditBottomSheet(Map<String, dynamic> vehicle) {
    final nameController = TextEditingController(text: vehicle['name'] ?? '');
    final hourlyRateController = TextEditingController(
        text: _getRate(vehicle, 'hourly_rate') > 0 ? _getRate(vehicle, 'hourly_rate').toStringAsFixed(0) : '');
    final dailyRateController = TextEditingController(
        text: _getRate(vehicle, 'daily_rate') > 0 ? _getRate(vehicle, 'daily_rate').toStringAsFixed(0) : '');
    final weeklyRateController = TextEditingController(
        text: _getRate(vehicle, 'weekly_rate') > 0 ? _getRate(vehicle, 'weekly_rate').toStringAsFixed(0) : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                      'Edit Vehicle',
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
                          _buildEditTextField(
                            controller: nameController,
                            label: 'Vehicle Name',
                            hint: 'Enter vehicle name',
                            icon: Icons.directions_car,
                          ),
                          const SizedBox(height: 16),
                          _buildEditTextField(
                            controller: hourlyRateController,
                            label: 'Hourly Rate (₹)',
                            hint: 'Enter hourly rate',
                            icon: Icons.speed,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          _buildEditTextField(
                            controller: dailyRateController,
                            label: 'Daily Rate (₹)',
                            hint: 'Enter daily rate',
                            icon: Icons.calendar_today,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          _buildEditTextField(
                            controller: weeklyRateController,
                            label: 'Weekly Rate (₹)',
                            hint: 'Enter weekly rate',
                            icon: Icons.date_range,
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final vehicleId = _getVehicleId(vehicle);
                                final authProvider = Provider.of<AuthProvider>(context, listen: false);

                                final success = await authProvider.updateVehicle(
                                  vehicleId,
                                  name: nameController.text.trim(),
                                  hourlyRate: hourlyRateController.text.isNotEmpty ? int.tryParse(hourlyRateController.text) : null,
                                  dailyRate: dailyRateController.text.isNotEmpty ? int.tryParse(dailyRateController.text) : null,
                                  weeklyRate: weeklyRateController.text.isNotEmpty ? int.tryParse(weeklyRateController.text) : null,
                                );

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Vehicle updated successfully'),
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                    _loadVehicles();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Failed to update vehicle'),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Update Vehicle'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEditTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              prefixIcon: Icon(icon, color: Colors.grey, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  void _showStatusBottomSheet(Map<String, dynamic> vehicle) {
    String selectedStatus = _vehicleStatus(vehicle);
    
    if (selectedStatus != 'available' && selectedStatus != 'unavailable') {
      selectedStatus = 'unavailable';
    }
    
    if (_vehicleStatus(vehicle) == 'on_rent') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot change status of a vehicle that is on rent'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            String localSelectedStatus = selectedStatus;
            
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
                      'Update Status',
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: localSelectedStatus,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'available', child: Text('Available')),
                                DropdownMenuItem(value: 'unavailable', child: Text('Unavailable (Maintenance/Other)')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setModalState(() {
                                    localSelectedStatus = value;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Note: "Unavailable" status is used for maintenance or when vehicle is not ready for rent',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                            final vehicleId = _getVehicleId(vehicle);
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);

                            final success = await authProvider.updateVehicleStatus(
                              vehicleId,
                              status: localSelectedStatus,
                              reason: null,
                            );

                            if (context.mounted) {
                              Navigator.pop(context);
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Status updated to ${localSelectedStatus == 'available' ? 'Available' : 'Unavailable'} successfully'),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                _loadVehicles();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to update status'),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Update Status'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteBottomSheet(Map<String, dynamic> vehicle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    const Text('Delete Vehicle', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Are you sure you want to delete "${vehicle['name'] ?? 'this vehicle'}"? This action cannot be undone.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                final vehicleId = _getVehicleId(vehicle);
                                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                final success = await authProvider.deleteVehicle(vehicleId);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Vehicle deleted successfully'), backgroundColor: Colors.green),
                                    );
                                    _loadVehicles();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to delete vehicle'), backgroundColor: Colors.red),
                                    );
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Delete'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isLoadingWallet) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leadingWidth: 120,
          title: const Text('Vehicles', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: -0.5)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.grey.shade900,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen())),
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
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
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.add, color: Colors.grey.shade900),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddVehicleScreen())),
            ),
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
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
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

    final int totalCount = _vehicles.length;
    final int availableCount = _vehicles.where((item) => _vehicleStatus(item) == 'available').length;
    final int onRentCount = _vehicles.where((item) => _vehicleStatus(item) == 'on_rent').length;
    final int unavailableCount = _vehicles.where((item) => _vehicleStatus(item) == 'unavailable').length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leadingWidth: 120,
        title: const Text('Vehicles', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22, letterSpacing: -0.5)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey.shade900,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const WalletScreen())),
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
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
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.grey.shade900),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddVehicleScreen())),
          ),
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
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
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
          await _loadVehicles();
          await _loadUnreadNotificationCount();
        },
        color: Colors.black,
        child: Column(
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
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search by name or number plate...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey.shade500),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ),

            // Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All ($totalCount)', 'all', _selectedFilter == 'all', Colors.black),
                    const SizedBox(width: 8),
                    _buildFilterChip('Available ($availableCount)', 'available', _selectedFilter == 'available', Colors.green),
                    const SizedBox(width: 8),
                    _buildFilterChip('On Rent ($onRentCount)', 'on_rent', _selectedFilter == 'on_rent', Colors.orange),
                    const SizedBox(width: 8),
                    _buildFilterChip('Unavailable ($unavailableCount)', 'unavailable', _selectedFilter == 'unavailable', Colors.red),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Vehicles List
            Expanded(
              child: _filteredVehicles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text('No vehicles found', style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredVehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = _filteredVehicles[index];
                        final status = _vehicleStatus(vehicle);
                        final statusColor = _getStatusColor(status);
                        final isAvailable = status == 'available';
                        final isOnRent = status == 'on_rent';
                        final hourlyRate = _getFormattedRate(vehicle, 'hourly_rate');
                        final dailyRate = _getFormattedRate(vehicle, 'daily_rate');
                        final weeklyRate = _getFormattedRate(vehicle, 'weekly_rate');

                        return Container(
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
                                child: Row(
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        _vehicleType(vehicle).toLowerCase() == 'car' || _vehicleType(vehicle).toLowerCase() == 'suv'
                                            ? Icons.directions_car
                                            : Icons.motorcycle,
                                        size: 35,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            vehicle['name'] ?? 'Unknown',
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _vehicleNumberPlate(vehicle),
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          // Dynamic pricing display
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              if (hourlyRate.isNotEmpty)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'Hourly: $hourlyRate',
                                                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                                                  ),
                                                ),
                                              if (dailyRate.isNotEmpty)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'Daily: $dailyRate',
                                                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                                                  ),
                                                ),
                                              if (weeklyRate.isNotEmpty)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade100,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'Weekly: $weeklyRate',
                                                    style: const TextStyle(fontSize: 10, color: Colors.black54),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getStatusText(status),
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: isOnRent ? null : () => _showEditBottomSheet(vehicle),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: isOnRent ? Colors.grey.shade200 : Colors.grey.shade300),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          disabledBackgroundColor: Colors.grey.shade100,
                                        ),
                                        child: Text('Edit', style: TextStyle(color: isOnRent ? Colors.grey.shade400 : null)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: isOnRent ? null : () => _showStatusBottomSheet(vehicle),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: isOnRent ? Colors.grey.shade200 : Colors.grey.shade300),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          disabledBackgroundColor: Colors.grey.shade100,
                                        ),
                                        child: Text('Status', style: TextStyle(color: isOnRent ? Colors.grey.shade400 : null)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: isAvailable
                                            ? () => Navigator.push(
                                                context,
                                                MaterialPageRoute(builder: (context) => NewRentalScreen(vehicleId: _getVehicleId(vehicle))),
                                              )
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          disabledBackgroundColor: Colors.grey.shade300,
                                        ),
                                        child: const Text('Rent'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: isOnRent ? null : () => _showDeleteBottomSheet(vehicle),
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(color: isOnRent ? Colors.grey.shade200 : Colors.red.shade400),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      foregroundColor: isOnRent ? Colors.grey.shade400 : Colors.red.shade400,
                                      disabledBackgroundColor: Colors.grey.shade100,
                                    ),
                                    child: Text('Delete', style: TextStyle(color: isOnRent ? Colors.grey.shade400 : Colors.red.shade400)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
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
        currentIndex: _selectedIndex,
        onTap: _onNavBarTap,
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isSelected, Color color) {
    return FilterChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade700, fontSize: 13)),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedFilter = value;
        });
      },
      backgroundColor: Colors.grey.shade100,
      selectedColor: color,
      checkmarkColor: Colors.white,
      showCheckmark: false,
    );
  }
}