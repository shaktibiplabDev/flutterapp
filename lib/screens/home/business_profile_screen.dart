import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../widgets/location_picker.dart';
import 'package:latlong2/latlong.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _displayAddressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _gstController = TextEditingController();
  final _legalNameController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingLogo = false;
  Map<String, dynamic>? _businessData;
  Map<String, dynamic>? _gstData;
  LatLng? _location;
  String _savedAddress = '';
  File? _selectedLogo;
  String? _logoUrl;
  
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadBusinessData();
  }
  
  @override
  void dispose() {
    _displayNameController.dispose();
    _displayAddressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _gstController.dispose();
    _legalNameController.dispose();
    super.dispose();
  }
  
  Future<void> _loadBusinessData() async {
    setState(() => _isLoading = true);
    final apiService = ApiService();
    
    try {
      final profileResponse = await apiService.getProfile();
      final gstResponse = await apiService.getGstStatus();
      
      if (profileResponse['success'] == true && profileResponse['data'] != null) {
        final data = profileResponse['data'];
        
        _businessData = data['business'] ?? {};
        _gstData = gstResponse['data'];
        _logoUrl = _businessData?['logo_url'];
        
        double lat = 20.5937;
        double lng = 78.9629;
        
        if (data['location'] != null) {
          lat = double.tryParse(data['location']['latitude'].toString()) ?? 20.5937;
          lng = double.tryParse(data['location']['longitude'].toString()) ?? 78.9629;
        }
        
        final displayName = _businessData?['display_name'] ?? '';
        final displayAddress = _businessData?['display_address'] ?? '';
        final businessPhone = _businessData?['phone'] ?? '';
        final businessEmail = _businessData?['email'] ?? '';
        final legalName = _businessData?['legal_name'] ?? _gstData?['legal_name'] ?? '';
        final gstNumber = _businessData?['gst_number'] ?? _gstData?['gst_number'] ?? '';
        
        if (mounted) {
          setState(() {
            _location = LatLng(lat, lng);
            _savedAddress = displayAddress;
            
            _displayNameController.text = displayName;
            _displayAddressController.text = displayAddress;
            _phoneController.text = businessPhone;
            _emailController.text = businessEmail;
            _legalNameController.text = legalName;
            _gstController.text = gstNumber;
            
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading business data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _pickLogo() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Upload Business Logo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, size: 28),
              title: const Text('Take a photo'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );
                if (image != null && mounted) {
                  setState(() {
                    _selectedLogo = File(image.path);
                  });
                  await _uploadLogo();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, size: 28),
              title: const Text('Choose from gallery'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? image = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                );
                if (image != null && mounted) {
                  setState(() {
                    _selectedLogo = File(image.path);
                  });
                  await _uploadLogo();
                }
              },
            ),
            if (_logoUrl != null && _logoUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, size: 28, color: Colors.red),
                title: const Text('Remove logo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Contact support to remove logo'),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
  
  Future<void> _uploadLogo() async {
    if (_selectedLogo == null) return;
    
    setState(() => _isUploadingLogo = true);
    final apiService = ApiService();
    
    try {
      final response = await apiService.uploadBusinessLogo(_selectedLogo!);
      
      if (response['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo uploaded successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadBusinessData();
        setState(() {
          _selectedLogo = null;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to upload logo'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingLogo = false);
      }
    }
  }
  
  Future<void> _saveBusinessProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    final apiService = ApiService();
    
    try {
      final displayResponse = await apiService.updateBusinessDisplay(
        displayName: _displayNameController.text,
        displayAddress: _displayAddressController.text,
        phone: _phoneController.text,
        email: _emailController.text,
      );
      
      if (displayResponse['success'] != true) {
        throw Exception(displayResponse['message'] ?? 'Failed to update business info');
      }
      
      if (_location != null) {
        await apiService.updateBusinessLocation(
          latitude: _location!.latitude,
          longitude: _location!.longitude,
          address: _displayAddressController.text,
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Business profile updated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
        await _loadBusinessData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
  
  Future<void> _verifyGST() async {
    if (_gstController.text.length != 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter valid 15-digit GST number'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    final apiService = ApiService();
    
    try {
      final response = await apiService.addGstNumber(
        gstNumber: _gstController.text.toUpperCase(),
        businessName: _legalNameController.text,
      );
      
      if (response['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GST verified! Business is now verified'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadBusinessData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'GST verification failed'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    final isVerified = (_businessData?['gst_verified'] == true) || (_gstData?['is_verified'] == true);
    final hasBusinessData = _businessData != null && _businessData!.isNotEmpty;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Profile'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.grey.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBusinessData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo Section - Centered
              Center(
                child: _buildLogoSection(),
              ),
              
              const SizedBox(height: 24),
              
              // Info Banner
              if (!hasBusinessData)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Complete your business profile to become a verified business.',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Display Info Card
              _buildSectionCard(
                title: 'Business Information',
                icon: Icons.business,
                children: [
                  _buildTextField(
                    _displayNameController, 
                    'Business Display Name', 
                    Icons.storefront, 
                    validator: true,
                    hint: 'Your business name (shown to customers)',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _displayAddressController, 
                    'Business Display Address', 
                    Icons.location_on, 
                    maxLines: 2, 
                    validator: true,
                    hint: 'Your business address (shown to customers)',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _phoneController, 
                    'Business Phone', 
                    Icons.phone, 
                    keyboardType: TextInputType.phone,
                    hint: 'Contact phone number',
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _emailController, 
                    'Business Email', 
                    Icons.email, 
                    keyboardType: TextInputType.emailAddress,
                    hint: 'Contact email address',
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Location Card with improved styling
              _buildSectionCard(
                title: 'Business Location',
                icon: Icons.map,
                subtitle: 'Current location shown on map. Tap to change.',
                children: [
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: LocationPicker(
                        initialLocation: _location,
                        initialAddress: _displayAddressController.text.isNotEmpty 
                            ? _displayAddressController.text 
                            : _savedAddress,
                        onLocationSelected: (lat, lng, address) {
                          setState(() {
                            _location = LatLng(lat, lng);
                            _displayAddressController.text = address;
                            _savedAddress = address;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.shade50,
                          Colors.blue.shade100,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.location_on, size: 18, color: Colors.blue.shade700),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected Location',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _displayAddressController.text.isNotEmpty 
                                    ? _displayAddressController.text 
                                    : 'Tap on map to select location',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade800,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // GST Card
              _buildSectionCard(
                title: 'GST Details',
                icon: Icons.receipt,
                subtitle: isVerified 
                    ? '✓ Verified Business - GST details are locked' 
                    : 'Add GST to become a verified business',
                children: [
                  _buildTextField(
                    _legalNameController, 
                    'Legal Business Name', 
                    Icons.business,
                    hint: 'Enter your registered business name',
                    enabled: !isVerified,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    _gstController, 
                    'GST Number', 
                    Icons.confirmation_number, 
                    keyboardType: TextInputType.text,
                    hint: 'Enter 15-digit GST number',
                    enabled: !isVerified,
                    suffix: isVerified 
                        ? const Icon(Icons.verified, color: Colors.green)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (!isVerified)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _verifyGST,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Verify GST', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.verified, color: Colors.green.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'GST Verified',
                                  style: TextStyle(
                                    fontSize: 13, 
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                Text(
                                  'GST Number: ${_gstController.text.isNotEmpty ? _gstController.text : (_businessData?['gst_number'] ?? '')}',
                                  style: TextStyle(fontSize: 11, color: Colors.green.shade600),
                                ),
                                Text(
                                  'Verified on ${_gstData?['verified_at']?.toString().split('T').first ?? _businessData?['gst_verified_at']?.toString().split('T').first ?? ''}',
                                  style: TextStyle(fontSize: 11, color: Colors.green.shade600),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Verification Status Card
              _buildVerificationStatusCard(isVerified),
              
              const SizedBox(height: 24),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveBusinessProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLogoSection() {
    return Container(
      width: 140,
      height: 140,
      padding: const EdgeInsets.all(0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey.shade100,
                  Colors.grey.shade200,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300.withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _pickLogo,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: _isUploadingLogo
                    ? const Center(
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (_selectedLogo != null
                        ? Image.file(_selectedLogo!, fit: BoxFit.cover)
                        : (_logoUrl != null && _logoUrl!.isNotEmpty
                            ? Image.network(
                                _logoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.store,
                                    size: 50,
                                    color: Colors.grey.shade400,
                                  );
                                },
                              )
                            : Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: Colors.grey.shade400,
                              ))),
              ),
            ),
          ),
          // Camera icon overlay
          Positioned(
            bottom: 5,
            right: 5,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildVerificationStatusCard(bool isVerified) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isVerified 
              ? [Colors.green.shade50, Colors.green.shade100]
              : [Colors.orange.shade50, Colors.orange.shade100],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVerified ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Icon(
              isVerified ? Icons.verified_user : Icons.info_outline,
              color: isVerified ? Colors.green.shade700 : Colors.orange.shade700,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVerified ? 'Verified Business' : 'Verification Pending',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isVerified ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isVerified 
                      ? 'Your business is verified. You can access all features.'
                      : 'Complete your GST verification to become a verified business and unlock additional features.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isVerified ? Colors.green.shade600 : Colors.orange.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade50,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: Colors.grey.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool validator = false,
    Widget? suffix,
    String? hint,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: TextStyle(
            fontSize: 13, 
            fontWeight: FontWeight.w500, 
            color: enabled ? Colors.grey.shade700 : Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          enabled: enabled,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: enabled ? Colors.grey.shade500 : Colors.grey.shade400),
            suffixIcon: suffix,
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade700, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            fillColor: enabled ? Colors.white : Colors.grey.shade50,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: validator && enabled ? (v) => v == null || v.isEmpty ? 'Required' : null : null,
        ),
      ],
    );
  }
}