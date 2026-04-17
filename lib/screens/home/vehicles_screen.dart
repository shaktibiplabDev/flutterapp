import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'home_screen.dart';
import 'bookings_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';
import 'add_vehicle_screen.dart';
import 'new_rental_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadData();
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
      if (!mounted) return;
      setState(() {
        _vehicles = vehiclesList;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading vehicles: $e');
      if (!mounted) return;
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

    filtered.sort((a, b) {
      final dateA = DateTime.tryParse(_stringValue(a['created_at']));
      final dateB = DateTime.tryParse(_stringValue(b['created_at']));
      return dateB?.compareTo(dateA ?? DateTime(1970)) ?? 0;
    });

    return filtered;
  }

  List<Map<String, dynamic>> _extractVehicleList(dynamic data) {
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
    return const [];
  }

  String _stringValue(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _vehicleStatus(Map<String, dynamic> vehicle) {
    final value = _stringValue(vehicle['status']).toLowerCase();
    
    // Map 'on_rent' to 'on_rent' (keep as is)
    if (value == 'on_rent' || value == 'onrent' || value == 'rented' || value == 'in_progress') {
      return 'on_rent';
    }
    
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

  String _vehicleDailyRate(Map<String, dynamic> vehicle) {
    final daily = vehicle['daily_rate'] ?? vehicle['dailyRate'];
    if (daily is num) return daily.toStringAsFixed(0);
    return _stringValue(daily, fallback: '0');
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
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

  String _getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'available':
        return 'Available';
      case 'on_rent':
        return 'On Rent';
      case 'unavailable':
        return 'Unavailable';
      default:
        return status ?? 'Unknown';
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
      // Already on vehicles
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

  // ==================== EDIT VEHICLE BOTTOM SHEET ====================
  void _showEditBottomSheet(Map<String, dynamic> vehicle) {
    final nameController = TextEditingController(text: vehicle['name'] ?? '');
    final hourlyRateController = TextEditingController(
        text: vehicle['hourly_rate']?.toString() ?? '');
    final dailyRateController = TextEditingController(
        text: vehicle['daily_rate']?.toString() ?? '');

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
                        _buildBottomSheetTextField(
                          controller: nameController,
                          label: 'Vehicle Name',
                          hint: 'Enter vehicle name',
                        ),
                        const SizedBox(height: 16),
                        _buildBottomSheetTextField(
                          controller: hourlyRateController,
                          label: 'Hourly Rate (₹)',
                          hint: 'Enter hourly rate',
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        _buildBottomSheetTextField(
                          controller: dailyRateController,
                          label: 'Daily Rate (₹)',
                          hint: 'Enter daily rate',
                          keyboardType: TextInputType.number,
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
                          final vehicleId = vehicle['id'].toString();
                          final authProvider = Provider.of<AuthProvider>(
                              context,
                              listen: false);

                          final success = await authProvider.updateVehicle(
                            vehicleId,
                            name: nameController.text.trim(),
                            hourlyRate: int.tryParse(hourlyRateController.text),
                            dailyRate: int.tryParse(dailyRateController.text),
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
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Update Vehicle',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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

  // ==================== UPDATE STATUS BOTTOM SHEET ====================
  void _showStatusBottomSheet(Map<String, dynamic> vehicle) {
    String selectedStatus = _vehicleStatus(vehicle);
    // Only allow toggling between available and unavailable
    if (selectedStatus != 'available' && selectedStatus != 'unavailable') {
      selectedStatus = 'unavailable';
    }
    
    // Don't allow status change if vehicle is on rent
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
                            value: selectedStatus,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'available',
                                  child: Text('Available')),
                              DropdownMenuItem(
                                  value: 'unavailable',
                                  child: Text('Unavailable (Maintenance/Other)')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedStatus = value!;
                              });
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
                          final vehicleId = vehicle['id'].toString();
                          final authProvider = Provider.of<AuthProvider>(
                              context,
                              listen: false);

                          final success = await authProvider.updateVehicleStatus(
                            vehicleId,
                            status: selectedStatus,
                            reason: null, // No reason needed for unavailable
                          );

                          if (context.mounted) {
                            Navigator.pop(context);

                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Status updated to ${selectedStatus == 'available' ? 'Available' : 'Unavailable'} successfully'),
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
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Update Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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

  // ==================== DELETE VEHICLE BOTTOM SHEET ====================
  void _showDeleteBottomSheet(Map<String, dynamic> vehicle) {
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
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Delete Vehicle',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Are you sure you want to delete "${vehicle['name'] ?? 'this vehicle'}"? This action cannot be undone.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final vehicleId = vehicle['id'].toString();
                              final authProvider = Provider.of<AuthProvider>(
                                  context,
                                  listen: false);

                              final success = await authProvider.deleteVehicle(
                                  vehicleId);

                              if (context.mounted) {
                                Navigator.pop(context);

                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Vehicle deleted successfully'),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  _loadVehicles();
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Failed to delete vehicle'),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Delete',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
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
      ),
    );
  }

  Widget _buildBottomSheetTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
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
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isLoadingWallet) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          leadingWidth: 120,
          title: const Text(
            'Vehicles',
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
              icon: Icon(Icons.add, color: Colors.grey.shade900),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AddVehicleScreen()),
                );
              },
            ),
            IconButton(
              icon: Stack(
                children: [
                  Icon(Icons.notifications_none, color: Colors.grey.shade700),
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
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notifications coming soon'),
                    backgroundColor: Colors.grey,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.grey),
        ),
      );
    }

    // Calculate counts
    int totalCount = _vehicles.length;
    int availableCount = _vehicles.where((item) => _vehicleStatus(item) == 'available').length;
    int onRentCount = _vehicles.where((item) => _vehicleStatus(item) == 'on_rent').length;
    int unavailableCount = _vehicles.where((item) => _vehicleStatus(item) == 'unavailable').length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leadingWidth: 120,
        title: const Text(
          'Vehicles',
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
            icon: Icon(Icons.add, color: Colors.grey.shade900),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AddVehicleScreen()),
              );
            },
          ),
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.notifications_none, color: Colors.grey.shade700),
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notifications coming soon'),
                  backgroundColor: Colors.grey,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
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
                  hintText: 'Search by name or number plate...',
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

          // Filter Chips
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
                    label: Text('Available ($availableCount)',
                        style: TextStyle(
                          color: _selectedFilter == 'available'
                              ? Colors.white
                              : Colors.grey.shade700,
                        )),
                    selected: _selectedFilter == 'available',
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = 'available';
                      });
                    },
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text('On Rent ($onRentCount)',
                        style: TextStyle(
                          color: _selectedFilter == 'on_rent'
                              ? Colors.white
                              : Colors.grey.shade700,
                        )),
                    selected: _selectedFilter == 'on_rent',
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = 'on_rent';
                      });
                    },
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text('Unavailable ($unavailableCount)',
                        style: TextStyle(
                          color: _selectedFilter == 'unavailable'
                              ? Colors.white
                              : Colors.grey.shade700,
                        )),
                    selected: _selectedFilter == 'unavailable',
                    onSelected: (selected) {
                      setState(() {
                        _selectedFilter = 'unavailable';
                      });
                    },
                    backgroundColor: Colors.grey.shade100,
                    selectedColor: Colors.red,
                  ),
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
                        Icon(
                          Icons.directions_car_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No vehicles found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadVehicles,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredVehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = _filteredVehicles[index];
                        final status = _vehicleStatus(vehicle);
                        final statusColor = _getStatusColor(status);
                        final isAvailable = status == 'available';
                        final isOnRent = status == 'on_rent';

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
                                        _vehicleType(vehicle).toLowerCase() ==
                                                    'car' ||
                                                _vehicleType(
                                                      vehicle,
                                                    ).toLowerCase() ==
                                                    'suv'
                                            ? Icons.directions_car
                                            : Icons.motorcycle,
                                        size: 35,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            vehicle['name'] ?? 'Unknown',
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
                                            _vehicleNumberPlate(vehicle),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.speed,
                                                size: 14,
                                                color: Colors.grey.shade500,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '₹${_vehicleDailyRate(vehicle)}/day',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.grey.shade700,
                                                ),
                                              ),
                                            ],
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
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getStatusText(status),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: statusColor,
                                        ),
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
                                        onPressed: isOnRent
                                            ? null
                                            : () {
                                                _showEditBottomSheet(vehicle);
                                              },
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                              color: isOnRent
                                                  ? Colors.grey.shade200
                                                  : Colors.grey.shade300),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          disabledBackgroundColor:
                                              Colors.grey.shade100,
                                        ),
                                        child: Text(
                                          'Edit',
                                          style: TextStyle(
                                            color: isOnRent
                                                ? Colors.grey.shade400
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: isOnRent
                                            ? null
                                            : () {
                                                _showStatusBottomSheet(vehicle);
                                              },
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(
                                              color: isOnRent
                                                  ? Colors.grey.shade200
                                                  : Colors.grey.shade300),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          disabledBackgroundColor:
                                              Colors.grey.shade100,
                                        ),
                                        child: Text(
                                          'Status',
                                          style: TextStyle(
                                            color: isOnRent
                                                ? Colors.grey.shade400
                                                : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: isAvailable
                                            ? () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => NewRentalScreen(
                                                      vehicleId: vehicle['id'].toString(),
                                                    ),
                                                  ),
                                                );
                                              }
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.black,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          disabledBackgroundColor:
                                              Colors.grey.shade300,
                                        ),
                                        child: const Text('Rent'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 12, right: 12, bottom: 12),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: isOnRent
                                        ? null
                                        : () {
                                            _showDeleteBottomSheet(vehicle);
                                          },
                                    style: OutlinedButton.styleFrom(
                                      side: BorderSide(
                                          color: isOnRent
                                              ? Colors.grey.shade200
                                              : Colors.red.shade400),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      foregroundColor: isOnRent
                                          ? Colors.grey.shade400
                                          : Colors.red.shade400,
                                      disabledBackgroundColor:
                                          Colors.grey.shade100,
                                    ),
                                    child: Text(
                                      'Delete',
                                      style: TextStyle(
                                        color: isOnRent
                                            ? Colors.grey.shade400
                                            : Colors.red.shade400,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_outlined),
            label: 'Vehicles',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onNavBarTap,
      ),
    );
  }
}