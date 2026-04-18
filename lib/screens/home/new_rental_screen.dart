import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'home_screen.dart';
import 'vehicles_screen.dart';
import 'bookings_screen.dart';
import 'profile_screen.dart';
import 'wallet_screen.dart';
import 'notifications_screen.dart';

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
  List<Map<String, dynamic>> _filteredVehicles = [];
  Map<String, dynamic>? _selectedVehicle;
  bool _isLoadingVehicles = true;
  String _searchQuery = '';
  
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
  
  // Notifications
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadUnreadNotificationCount();
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
          _filteredVehicles = List<Map<String, dynamic>>.from(data);
        } else if (data is Map && data.containsKey('vehicles')) {
          _availableVehicles = List<Map<String, dynamic>>.from(data['vehicles']);
          _filteredVehicles = List<Map<String, dynamic>>.from(data['vehicles']);
        }
        _filterVehicles();
      }
    } catch (e) {
      print('Error loading vehicles: $e');
    } finally {
      setState(() {
        _isLoadingVehicles = false;
      });
    }
  }

  void _filterVehicles() {
    if (_searchQuery.isEmpty) {
      _filteredVehicles = List.from(_availableVehicles);
    } else {
      _filteredVehicles = _availableVehicles.where((vehicle) {
        final name = vehicle['name']?.toString().toLowerCase() ?? '';
        final numberPlate = vehicle['number_plate']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || numberPlate.contains(query);
      }).toList();
    }
    setState(() {});
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

  void _showImagePickerOptions(bool isLicense) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
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
              'Choose Option',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildPickerOption(
              icon: Icons.camera_alt_outlined,
              title: 'Take Photo',
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, isLicense);
              },
            ),
            _buildPickerOption(
              icon: Icons.photo_library_outlined,
              title: 'Choose from Gallery',
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, isLicense);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showVideoPickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
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
              'Choose Option',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildPickerOption(
              icon: Icons.videocam_outlined,
              title: 'Record Video',
              onTap: () {
                Navigator.pop(context);
                _pickVideo(ImageSource.camera);
              },
            ),
            _buildPickerOption(
              icon: Icons.video_library_outlined,
              title: 'Choose from Gallery',
              onTap: () {
                Navigator.pop(context);
                _pickVideo(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 24, color: Colors.grey.shade700),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
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

  void _showSignImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
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
              'Choose Option',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildPickerOption(
              icon: Icons.camera_alt_outlined,
              title: 'Take Photo',
              onTap: () {
                Navigator.pop(context);
                _pickSignImage(ImageSource.camera);
              },
            ),
            _buildPickerOption(
              icon: Icons.photo_library_outlined,
              title: 'Choose from Gallery',
              onTap: () {
                Navigator.pop(context);
                _pickSignImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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

  void _showCustomerImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
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
              'Choose Option',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildPickerOption(
              icon: Icons.camera_alt_outlined,
              title: 'Take Photo',
              onTap: () {
                Navigator.pop(context);
                _pickCustomerImage(ImageSource.camera);
              },
            ),
            _buildPickerOption(
              icon: Icons.photo_library_outlined,
              title: 'Choose from Gallery',
              onTap: () {
                Navigator.pop(context);
                _pickCustomerImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    if (_isLoadingVehicles || _isLoadingWallet) {
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
      body: _currentPhase == 0 ? _buildPOSScreen() : _buildPhaseScreen(),
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
        'New Rental',
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
    );
  }

  Widget _buildPOSScreen() {
    return Column(
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
                _searchQuery = value;
                _filterVehicles();
              },
              decoration: InputDecoration(
                hintText: 'Search by name or number plate...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade500),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey.shade500),
                        onPressed: () {
                          _searchQuery = '';
                          _filterVehicles();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ),
        Expanded(
          child: _filteredVehicles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text('No vehicles found', style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredVehicles.length,
                  itemBuilder: (context, index) {
                    final vehicle = _filteredVehicles[index];
                    final isAvailable = vehicle['status']?.toString().toLowerCase() == 'available';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: _selectedVehicle?['id'] == vehicle['id'] ? Colors.grey.shade100 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedVehicle?['id'] == vehicle['id'] ? Colors.black : Colors.grey.shade200,
                          width: _selectedVehicle?['id'] == vehicle['id'] ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        onTap: isAvailable ? () => setState(() => _selectedVehicle = vehicle) : null,
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            vehicle['type'] == 'car' || vehicle['type'] == 'SUV' ? Icons.directions_car : Icons.motorcycle,
                            size: 30,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        title: Text(
                          vehicle['name'] ?? 'Unknown',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isAvailable ? Colors.grey.shade900 : Colors.grey.shade500,
                          ),
                        ),
                        subtitle: Text(
                          '₹${vehicle['daily_rate'] ?? 0}/day • ${vehicle['number_plate'] ?? ''}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        trailing: isAvailable
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Available',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Unavailable',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.red),
                                ),
                              ),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _selectedVehicle != null ? () => setState(() => _currentPhase = 1) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selected Vehicle Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _selectedVehicle?['type'] == 'car' || _selectedVehicle?['type'] == 'SUV'
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
                        _selectedVehicle?['name'] ?? 'Unknown',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${_selectedVehicle?['daily_rate'] ?? 0}/day • ${_selectedVehicle?['number_plate'] ?? ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Info Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A verification fee of ₹3 will be deducted from your wallet. This fee is non-refundable.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Form Title
          Text(
            'Customer Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
          ),
          const SizedBox(height: 16),

          // Form
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
                  hint: 'Enter DL number',
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

          // Verify Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isVerifying ? null : _phase1VerifyCustomer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: _isVerifying
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Verify & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhase2Screen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: _verifiedCustomer?['customer_photo_url'] != null
                            ? Image.network(
                                _verifiedCustomer!['customer_photo_url'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Icon(Icons.person, size: 35, color: Colors.grey.shade500),
                              )
                            : Icon(Icons.person, size: 35, color: Colors.grey.shade500),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _verifiedCustomer?['name'] ?? 'Customer Name',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _verifiedCustomer?['phone'] ?? 'Phone number',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Verified',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildDetailRow('License Number', _verifiedCustomer?['license_number'] ?? 'N/A'),
                const SizedBox(height: 12),
                _buildDetailRow('Date of Birth', _formatDate(_verifiedCustomer?['dob'])),
                const SizedBox(height: 12),
                _buildDetailRow('License Issue Date', _formatDate(_verifiedCustomer?['license_issue_date'])),
                const SizedBox(height: 12),
                _buildDetailRow('Valid Till', _formatDate(_verifiedCustomer?['license_validity']?['valid_to'])),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _verifiedCustomer?['address'] ?? 'Address not available',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.currency_rupee, size: 16, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verification Fee: ₹$_verificationFee',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade800),
                            ),
                            Text(
                              'Wallet Balance: ₹${_formatWalletAmount(_walletBalanceAfterFee)}',
                              style: TextStyle(fontSize: 11, color: Colors.amber.shade700),
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

          // Document Upload Title
          Text(
            'Upload Documents',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
          ),
          const SizedBox(height: 8),
          Text(
            'Please upload the following documents to proceed',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),

          // License Image
          _buildImagePickerWithOptions(
            label: 'Driving License',
            imageFile: _licenseImage,
            onTap: () => _showImagePickerOptions(true),
            required: true,
          ),
          const SizedBox(height: 16),

          // Aadhaar Image
          _buildImagePickerWithOptions(
            label: 'Aadhaar Card',
            imageFile: _aadhaarImage,
            onTap: () => _showImagePickerOptions(false),
            required: false,
            optional: true,
          ),
          const SizedBox(height: 24),

          // Upload Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isUploadingDocs ? null : _phase2UploadDocuments,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: _isUploadingDocs
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Upload & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhase3Screen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.grey.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Follow these steps:\n1. Download and review the rental agreement\n2. Sign the agreement and upload photo\n3. Take customer photo\n4. Record vehicle condition video (optional)',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Download Agreement Button
          if (_agreementPath != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isDownloadingAgreement ? null : _downloadAndOpenAgreement,
                icon: _isDownloadingAgreement
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.picture_as_pdf),
                label: Text(_isDownloadingAgreement ? 'Loading...' : 'Download Rental Agreement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          const SizedBox(height: 24),

          // Signed Agreement
          _buildImagePickerWithOptions(
            label: 'Signed Agreement',
            imageFile: _signedAgreementImage,
            onTap: () => _showSignImagePickerOptions(),
            required: true,
          ),
          const SizedBox(height: 16),

          // Customer with Vehicle
          _buildImagePickerWithOptions(
            label: 'Customer with Vehicle',
            imageFile: _customerWithVehicleImage,
            onTap: () => _showCustomerImagePickerOptions(),
            required: false,
            optional: true,
          ),
          const SizedBox(height: 16),

          // Vehicle Condition Video
          _buildVideoPickerWithOptions(
            label: 'Vehicle Condition Video',
            videoFile: _vehicleConditionVideo,
            onTap: () => _showVideoPickerOptions(),
          ),
          const SizedBox(height: 24),

          // Start Rental Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isCompletingRental ? null : _phase3CompleteRental,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: Colors.grey.shade300,
              ),
              child: _isCompletingRental
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Start Rental', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
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
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
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
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              prefixIcon: Icon(icon, color: Colors.grey, size: 20),
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
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
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
                hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                prefixIcon: Icon(icon, color: Colors.grey, size: 20),
                suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
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

  Widget _buildImagePickerWithOptions({
    required String label,
    required File? imageFile,
    required VoidCallback onTap,
    bool required = false,
    bool optional = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
            if (required) const Text(' *', style: TextStyle(color: Colors.red)),
            if (optional) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Optional', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 100,
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
                      Icon(Icons.cloud_upload_outlined, size: 32, color: Colors.grey.shade500),
                      const SizedBox(height: 8),
                      Text('Tap to upload', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPickerWithOptions({
    required String label,
    required File? videoFile,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Optional', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 100,
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
                        Icon(Icons.play_circle_filled, size: 32, color: Colors.green),
                        const SizedBox(height: 8),
                        Text('Video selected', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_outlined, size: 32, color: Colors.grey.shade500),
                      const SizedBox(height: 8),
                      Text('Tap to upload video', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}