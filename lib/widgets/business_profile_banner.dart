import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/home/business_profile_screen.dart';

/// Reusable business profile banner that shows when business profile is not created
class BusinessProfileBanner extends StatefulWidget {
  const BusinessProfileBanner({super.key});

  @override
  State<BusinessProfileBanner> createState() => _BusinessProfileBannerState();
}

class _BusinessProfileBannerState extends State<BusinessProfileBanner> {
  bool _hasBusinessProfile = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkBusinessProfile();
  }

  Future<void> _checkBusinessProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final response = await authProvider.getBusinessVerificationStatus();
      if (mounted) {
        final data = response['data'];
        final business = data?['business'];
        setState(() {
          // Business profile is complete if display_name, display_address, phone, and email exist
          _hasBusinessProfile = response['success'] == true && 
                               data != null &&
                               business != null &&
                               business['display_name'] != null &&
                               business['display_address'] != null &&
                               business['phone'] != null &&
                               business['email'] != null;
          _isChecking = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking business profile: $e');
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking || _hasBusinessProfile) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.business, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Business Profile Required',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade800,
                  ),
                ),
                Text(
                  'Create your business profile to use all features',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BusinessProfileScreen(),
                ),
              ).then((_) => _checkBusinessProfile());
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red.shade700,
              backgroundColor: Colors.red.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Create Now'),
          ),
        ],
      ),
    );
  }
}
