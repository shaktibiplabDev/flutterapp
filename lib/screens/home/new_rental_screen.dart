import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import '../../providers/auth_provider.dart';
import 'home_screen.dart';
import 'vehicles_screen.dart';
import 'bookings_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';

class NewRentalScreen extends StatefulWidget {
  final String? vehicleId;
  
  const NewRentalScreen({super.key, this.vehicleId});

  @override
  State<NewRentalScreen> createState() => _NewRentalScreenState();
}

class _NewRentalScreenState extends State<NewRentalScreen> {
  int _currentPhase = 0;
  int _selectedIndex = 1;
  
  // Phase 0 - Vehicle Selection
  List<Map<String, dynamic>> _availableVehicles = [];
  Map<String, dynamic>? _selectedVehicle;
  bool _isLoadingVehicles = true;
  
  // Phase 1 - Customer Verification
  final _customerFormKey = GlobalKey<FormState>();
  final _customerPhoneController = TextEditingController();
  final _dlNumberController = TextEditingController();
  final _dobController = TextEditingController();
  String? _verificationToken;
  int? _rentalId;
  Map<String, dynamic>? _verifiedCustomer;
  bool _isVerifying = false;
  int _walletBalanceAfterFee = 0;
  int _verificationFee = 0;
  
  // Phase 2 - Document Upload
  File? _licenseImage;
  File? _aadhaarImage;
  bool _isUploadingDocs = false;
  String? _agreementPath;
  bool _isDownloadingAgreement = false;
  
  // Phase 3 - Sign & Handover
  File? _signedAgreementImage;
  File? _customerWithVehicleImage;
  File? _vehicleConditionVideo;
  bool _isCompletingRental = false;
  
  // Wallet balance
  int _walletBalance = 0;
  bool _isLoadingWallet = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadVehicles(),
      _loadWalletBalance(),
    ]);
    
    if (widget.vehicleId != null && _availableVehicles.isNotEmpty) {
      final vehicle = _availableVehicles.firstWhere(
        (v) => v['id'].toString() == widget.vehicleId,
        orElse: () => {},
      );
      if (vehicle.isNotEmpty) {
        setState(() {
          _selectedVehicle = vehicle;
          _currentPhase = 1;
        });
      }
    }
  }

  Future<void> _loadVehicles() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final response = await authProvider.getAvailableVehicles();
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        if (data is List) {
          _availableVehicles = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('vehicles')) {
          _availableVehicles = List<Map<String, dynamic>>.from(data['vehicles']);
        }
        _availableVehicles.sort((a, b) {
          final statusA = a['status']?.toString().toLowerCase() ?? '';
          final statusB = b['status']?.toString().toLowerCase() ?? '';
          if (statusA == 'available' && statusB != 'available') return -1;
          if (statusA != 'available' && statusB == 'available') return 1;
          return 0;
        });
      }
    } catch (e) {
      print('Error loading vehicles: $e');
    } finally {
      setState(() {
        _isLoadingVehicles = false;
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _pickImage(ImageSource source, bool isLicense) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        if (isLicense) {
          _licenseImage = File(pickedFile.path);
        } else {
          _aadhaarImage = File(pickedFile.path);
        }
      });
    }
  }

  Future<void> _pickSignImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _signedAgreementImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickCustomerImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _customerWithVehicleImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: source);
    if (pickedFile != null) {
      setState(() {
        _vehicleConditionVideo = File(pickedFile.path);
      });
    }
  }

  Future<void> _downloadAndOpenAgreement() async {
    if (_agreementPath == null) return;
    
    setState(() {
      _isDownloadingAgreement = true;
    });
    
    try {
      final response = await http.get(Uri.parse(_agreementPath!));
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/rental_agreement_$_rentalId.pdf');
        await file.writeAsBytes(response.bodyBytes);
        
        if (!mounted) return;
        
        final result = await OpenFile.open(file.path);
        
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please install a PDF viewer app to view the agreement'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to download agreement'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to download agreement'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isDownloadingAgreement = false;
      });
    }
  }

  Future<void> _phase1VerifyCustomer() async {
    if (!_customerFormKey.currentState!.validate()) return;
    
    setState(() {
      _isVerifying = true;
    });
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final response = await authProvider.verifyDLAndSaveCustomer(
      vehicleId: _selectedVehicle!['id'].toString(),
      customerPhone: _customerPhoneController.text.trim(),
      dlNumber: _dlNumberController.text.trim(),
      dob: _dobController.text.trim(),
    );
    
    setState(() {
      _isVerifying = false;
    });
    
    if (response['success'] == true && response['data'] != null) {
      final data = response['data'];
      setState(() {
        _verificationToken = data['verification_token'];
        _rentalId = data['rental_id'];
        _verifiedCustomer = data['customer'];
        _walletBalanceAfterFee = data['wallet_balance'];
        _verificationFee = data['verification_fee'];
        _currentPhase = 2;
      });
      
      // Update wallet balance in provider
      await authProvider.fetchWalletBalance();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Customer verified successfully! Fee: ₹$_verificationFee'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'Verification failed'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _phase2UploadDocuments() async {
    if (_licenseImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload license image'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    if (_verificationToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification token missing. Please restart the process.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    setState(() {
      _isUploadingDocs = true;
    });
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final response = await authProvider.uploadDocuments(
      verificationToken: _verificationToken!,
      licenseImage: _licenseImage!,
      aadhaarImage: _aadhaarImage,
    );
    
    setState(() {
      _isUploadingDocs = false;
    });
    
    if (response['success'] == true && response['data'] != null) {
      setState(() {
        _agreementPath = response['data']['agreement_path'];
        _currentPhase = 3;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Documents uploaded successfully! Please download and sign the agreement.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'Document upload failed'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _phase3CompleteRental() async {
    if (_signedAgreementImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload signed agreement image'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    if (_rentalId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rental ID missing. Please restart the process.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    setState(() {
      _isCompletingRental = true;
    });
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final response = await authProvider.signAndHandover(
      rentalId: _rentalId!,
      signedAgreementImage: _signedAgreementImage!,
      customerWithVehicleImage: _customerWithVehicleImage,
      vehicleConditionVideo: _vehicleConditionVideo,
    );
    
    setState(() {
      _isCompletingRental = false;
    });
    
    if (response['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rental started successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const BookingsScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message'] ?? 'Failed to start rental'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
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

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildPhaseIndicator() {
    final phases = [
      {'title': 'Select Vehicle', 'icon': Icons.directions_car_outlined},
      {'title': 'Verify Customer', 'icon': Icons.verified_user_outlined},
      {'title': 'Upload Docs', 'icon': Icons.upload_file_outlined},
      {'title': 'Sign & Go', 'icon': Icons.edit_note_outlined},
    ];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      color: Colors.white,
      child: Row(
        children: List.generate(phases.length, (index) {
          final isActive = _currentPhase >= index;
          final isCompleted = _currentPhase > index;
          return Expanded(
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? Colors.black : Colors.grey.shade200,
                    border: Border.all(
                      color: isActive ? Colors.black : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, size: 22, color: Colors.white)
                        : Icon(
                            phases[index]['icon'] as IconData,
                            size: 22,
                            color: isActive ? Colors.white : Colors.grey.shade500,
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  phases[index]['title'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive ? Colors.black : Colors.grey.shade500,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (index < phases.length - 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 2,
                      color: isCompleted ? Colors.black : Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (iconColor ?? Colors.black).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor ?? Colors.black, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingVehicles || _isLoadingWallet) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.black),
              SizedBox(height: 16),
              Text('Loading...', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildPhaseIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _currentPhase == 0 ? _buildPOSScreen() : _buildPhaseScreen(),
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
        elevation: 8,
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
        'New Rental',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WalletScreen()),
          ),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.account_balance_wallet_outlined, size: 18, color: Colors.grey.shade700),
                const SizedBox(width: 6),
                Text(
                  '₹${_formatWalletAmount(_walletBalance)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
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
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notifications coming soon'),
              backgroundColor: Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPOSScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Select a vehicle from the list below to start the rental process',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Available Vehicles',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_availableVehicles.length} vehicles available for rent',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        _availableVehicles.isEmpty
            ? Center(
                child: Column(
                  children: [
                    Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No vehicles available',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _availableVehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = _availableVehicles[index];
                  final isAvailable = vehicle['status']?.toString().toLowerCase() == 'available';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: _selectedVehicle?['id'] == vehicle['id'] 
                          ? Colors.black.withOpacity(0.02) 
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedVehicle?['id'] == vehicle['id'] 
                            ? Colors.black 
                            : Colors.grey.shade200,
                        width: _selectedVehicle?['id'] == vehicle['id'] ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      onTap: isAvailable ? () => setState(() => _selectedVehicle = vehicle) : null,
                      leading: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          vehicle['type'] == 'car' || vehicle['type'] == 'SUV' 
                              ? Icons.directions_car 
                              : Icons.motorcycle,
                          size: 32,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      title: Text(
                        vehicle['name'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isAvailable ? Colors.black87 : Colors.grey.shade500,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${vehicle['daily_rate'] ?? 0}/day',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                          Text(
                            vehicle['number_plate'] ?? '',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                      trailing: isAvailable
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Available',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Unavailable',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                    ),
                  );
                },
              ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _selectedVehicle != null 
                ? () => setState(() => _currentPhase = 1) 
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: const Text(
              'Continue with Selected Vehicle',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseScreen() {
    switch (_currentPhase) {
      case 1: return _buildPhase1Screen();
      case 2: return _buildPhase2Screen();
      case 3: return _buildPhase3Screen();
      default: return const SizedBox();
    }
  }

  Widget _buildPhase1Screen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          icon: Icons.directions_car,
          title: _selectedVehicle?['name'] ?? 'Unknown',
          subtitle: '₹${_selectedVehicle?['daily_rate'] ?? 0}/day • ${_selectedVehicle?['number_plate'] ?? ''}',
          iconColor: Colors.green,
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'A verification fee of ₹50 will be deducted from your wallet. This fee is non-refundable.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Customer Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 16),
        Form(
          key: _customerFormKey,
          child: Column(
            children: [
              _buildTextField(
                controller: _customerPhoneController,
                label: 'Phone Number',
                hint: 'Enter 10-digit mobile number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Phone number is required';
                  if (v.length < 10) return 'Enter a valid 10-digit phone number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _dlNumberController,
                label: 'Driving License Number',
                hint: 'Enter DL number (e.g., DL-0420110012345)',
                icon: Icons.credit_card_outlined,
                validator: (v) => v == null || v.isEmpty ? 'License number is required' : null,
              ),
              const SizedBox(height: 16),
              _buildDateField(
                controller: _dobController,
                label: 'Date of Birth',
                hint: 'Select date of birth',
                icon: Icons.calendar_today_outlined,
                onTap: _selectDate,
                validator: (v) => v == null || v.isEmpty ? 'Date of birth is required' : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isVerifying ? null : _phase1VerifyCustomer,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: _isVerifying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Verify & Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhase2Screen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                      image: _verifiedCustomer?['customer_photo_url'] != null
                          ? DecorationImage(
                              image: NetworkImage(_verifiedCustomer!['customer_photo_url']),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _verifiedCustomer?['customer_photo_url'] == null
                        ? Icon(Icons.person, size: 40, color: Colors.grey.shade400)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _verifiedCustomer?['name'] ?? 'Customer Name',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _verifiedCustomer?['phone'] ?? 'Phone number',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              _buildDetailRow('License Number', _verifiedCustomer?['license_number'] ?? 'N/A'),
              const SizedBox(height: 12),
              _buildDetailRow('Date of Birth', _formatDate(_verifiedCustomer?['dob'])),
              const SizedBox(height: 12),
              _buildDetailRow('License Issue Date', _formatDate(_verifiedCustomer?['license_issue_date'])),
              const SizedBox(height: 12),
              _buildDetailRow('Valid Till', _formatDate(_verifiedCustomer?['license_validity']?['valid_to'])),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 18, color: Colors.grey.shade600),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _verifiedCustomer?['address'] ?? 'Address not available',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.currency_rupee, size: 18, color: Colors.amber.shade800),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Verification Fee: ₹$_verificationFee',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Wallet Balance after fee: ₹${_formatWalletAmount(_walletBalanceAfterFee)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Document Upload',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please upload the following documents to proceed',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),
        _buildImagePicker(
          label: 'Driving License',
          imageFile: _licenseImage,
          onTap: () => _pickImage(ImageSource.gallery, true),
          required: true,
        ),
        const SizedBox(height: 16),
        _buildImagePicker(
          label: 'Aadhaar Card',
          imageFile: _aadhaarImage,
          onTap: () => _pickImage(ImageSource.gallery, false),
          required: false,
          optional: true,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isUploadingDocs ? null : _phase2UploadDocuments,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: _isUploadingDocs
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Upload Documents & Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhase3Screen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Follow these steps to complete the rental process:\n'
                  '1. Download and review the rental agreement\n'
                  '2. Sign the agreement and take a photo\n'
                  '3. Take a photo of customer with the vehicle\n'
                  '4. Record a video of vehicle condition (optional)\n'
                  '5. Click "Start Rental" to begin',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (_agreementPath != null)
          ElevatedButton.icon(
            onPressed: _isDownloadingAgreement ? null : _downloadAndOpenAgreement,
            icon: _isDownloadingAgreement
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.picture_as_pdf, color: Colors.white),
            label: Text(_isDownloadingAgreement ? 'Loading...' : 'Download Rental Agreement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        const SizedBox(height: 24),
        Text(
          'Signed Documents & Photos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 16),
        _buildImagePicker(
          label: 'Signed Agreement',
          imageFile: _signedAgreementImage,
          onTap: () => _pickSignImage(ImageSource.gallery),
          required: true,
          hint: 'Upload photo of signed agreement',
        ),
        const SizedBox(height: 16),
        _buildImagePicker(
          label: 'Customer with Vehicle',
          imageFile: _customerWithVehicleImage,
          onTap: () => _pickCustomerImage(ImageSource.gallery),
          required: false,
          optional: true,
          hint: 'Take photo of customer standing with the vehicle',
        ),
        const SizedBox(height: 16),
        _buildVideoPicker(
          label: 'Vehicle Condition Video',
          videoFile: _vehicleConditionVideo,
          onTap: () => _pickVideo(ImageSource.gallery),
          hint: 'Record a short video showing vehicle condition',
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isCompletingRental ? null : _phase3CompleteRental,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: _isCompletingRental
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Start Rental',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
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
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: TextFormField(
              controller: controller,
              enabled: false,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(icon, color: Colors.grey.shade600, size: 20),
                suffixIcon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: validator,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker({
    required String label,
    required File? imageFile,
    required VoidCallback onTap,
    bool required = false,
    bool optional = false,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            if (required) ...[
              const SizedBox(width: 4),
              const Text('*', style: TextStyle(color: Colors.red, fontSize: 16)),
            ],
            if (optional) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Optional',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: imageFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(imageFile, fit: BoxFit.cover),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Icon(Icons.check_circle, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 40, color: Colors.grey.shade500),
                      const SizedBox(height: 8),
                      Text(
                        hint ?? 'Tap to upload image',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPicker({
    required String label,
    required File? videoFile,
    required VoidCallback onTap,
    String? hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Optional',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: videoFile != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_circle_filled, size: 48, color: Colors.green.shade700),
                        const SizedBox(height: 8),
                        Text(
                          'Video selected',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_outlined, size: 40, color: Colors.grey.shade500),
                      const SizedBox(height: 8),
                      Text(
                        hint ?? 'Tap to upload video',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}