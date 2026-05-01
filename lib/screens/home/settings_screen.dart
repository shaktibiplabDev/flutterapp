import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../legal/legal_page_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _emailNotifications = true;
  bool _smsNotifications = false;
  String _language = 'en';
  String _itemsPerPage = '15';
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    final apiService = ApiService();
    try {
      final response = await apiService.getSettings();
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _notificationsEnabled = response['data']['notifications_enabled'] ?? true;
          _emailNotifications = response['data']['email_notifications'] ?? true;
          _smsNotifications = response['data']['sms_notifications'] ?? false;
          _language = response['data']['language'] ?? 'en';
          _itemsPerPage = (response['data']['items_per_page'] ?? 15).toString();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _updateSetting(String key, dynamic value, String type) async {
    final apiService = ApiService();
    try {
      await apiService.updateSetting(key, value, type);
      // Show success feedback
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$key updated'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating $key: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update $key'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
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
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.grey.shade900,
      ),
      body: ListView(
        children: [
          _buildSection('Notifications', [
            SwitchListTile(
              title: const Text('Push Notifications'),
              subtitle: const Text('Receive push notifications for updates'),
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() => _notificationsEnabled = value);
                _updateSetting('notifications_enabled', value, 'boolean');
              },
              secondary: Icon(Icons.notifications, color: Colors.grey.shade600),
            ),
            SwitchListTile(
              title: const Text('Email Notifications'),
              subtitle: const Text('Receive email for important updates'),
              value: _emailNotifications,
              onChanged: (value) {
                setState(() => _emailNotifications = value);
                _updateSetting('email_notifications', value, 'boolean');
              },
              secondary: Icon(Icons.email, color: Colors.grey.shade600),
            ),
            SwitchListTile(
              title: const Text('SMS Notifications'),
              subtitle: const Text('Receive SMS for rental updates'),
              value: _smsNotifications,
              onChanged: (value) {
                setState(() => _smsNotifications = value);
                _updateSetting('sms_notifications', value, 'boolean');
              },
              secondary: Icon(Icons.sms, color: Colors.grey.shade600),
            ),
          ]),
          
          _buildSection('Preferences', [
            ListTile(
              title: const Text('Language'),
              subtitle: Text(_language == 'en' ? 'English' : 'हिंदी'),
              leading: Icon(Icons.language, color: Colors.grey.shade600),
              trailing: DropdownButton<String>(
                value: _language,
                items: const [
                  DropdownMenuItem(value: 'en', child: Text('English')),
                  DropdownMenuItem(value: 'hi', child: Text('हिंदी')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _language = value);
                    _updateSetting('language', value, 'string');
                  }
                },
              ),
            ),
            ListTile(
              title: const Text('Items Per Page'),
              subtitle: const Text('Number of items in lists'),
              leading: Icon(Icons.view_list, color: Colors.grey.shade600),
              trailing: DropdownButton<String>(
                value: _itemsPerPage,
                items: const ['15', '25', '50', '100'].map((value) {
                  return DropdownMenuItem(value: value, child: Text(value));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _itemsPerPage = value);
                    _updateSetting('items_per_page', int.parse(value), 'integer');
                  }
                },
              ),
            ),
          ]),
          
          _buildSection('Support', [
            ListTile(
              title: const Text('Privacy Policy'),
              leading: Icon(Icons.privacy_tip_outlined, color: Colors.grey.shade600),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLegalPage('privacy-policy'),
            ),
            ListTile(
              title: const Text('Terms of Service'),
              leading: Icon(Icons.description_outlined, color: Colors.grey.shade600),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLegalPage('terms-of-service'),
            ),
            ListTile(
              title: const Text('About Us'),
              leading: Icon(Icons.business, color: Colors.grey.shade600),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLegalPage('about'),
            ),
          ]),
          
          _buildSection('About', [
            ListTile(
              title: const Text('Version'),
              subtitle: const Text('1.0.0'),
              leading: Icon(Icons.info_outline, color: Colors.grey.shade600),
            ),
            ListTile(
              title: const Text('Developer'),
              subtitle: const Text('Versaero Technologies'),
              leading: Icon(Icons.code, color: Colors.grey.shade600),
            ),
          ]),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
  
  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Colors.grey.shade200),
              bottom: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
  
  void _showLegalPage(String slug) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LegalPageScreen(slug: slug),
      ),
    );
  }
}