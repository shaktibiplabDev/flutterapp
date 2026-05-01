import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class LegalPageScreen extends StatefulWidget {
  final String slug;
  
  const LegalPageScreen({
    super.key,
    required this.slug,
  });

  @override
  State<LegalPageScreen> createState() => _LegalPageScreenState();
}

class _LegalPageScreenState extends State<LegalPageScreen> {
  bool _isLoading = true;
  bool _isFromApi = false;
  String _errorMessage = '';
  
  // API Response Data
  String _title = '';
  String _content = '';
  String _lastUpdated = '';
  String _version = '';
  
  @override
  void initState() {
    super.initState();
    _loadContent();
  }
  
  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final response = await authProvider.getLegalPage(widget.slug);
    
    if (response['success'] == true && response['data'] != null) {
      final data = response['data'];
      
      // The HTML content is in the 'content' field
      String htmlContent = data['content'] ?? '';
      
      setState(() {
        _title = data['title'] ?? _getDefaultTitle();
        _content = htmlContent;
        _lastUpdated = data['updated_at'] ?? '';
        _version = data['version'] ?? '';
        _isFromApi = true;
        _isLoading = false;
      });
    } else {
      // Fallback to predefined content only if API fails
      setState(() {
        _title = _getDefaultTitle();
        _content = _getDefaultHtmlContent();
        _isFromApi = false;
        _isLoading = false;
        if (response['message'] != null) {
          _errorMessage = response['message'];
        }
      });
    }
  }
  
  String _getDefaultTitle() {
    switch (widget.slug) {
      case 'privacy-policy':
        return 'Privacy Policy';
      case 'terms-of-service':
        return 'Terms of Service';
      case 'about':
        return 'About EKiraya';
      default:
        return 'Legal Information';
    }
  }
  
  String _getDefaultHtmlContent() {
    switch (widget.slug) {
      case 'privacy-policy':
        return _getPrivacyPolicyHtml();
      case 'terms-of-service':
        return _getTermsOfServiceHtml();
      case 'about':
        return _getAboutHtml();
      default:
        return _getPrivacyPolicyHtml();
    }
  }
  
  String _getPrivacyPolicyHtml() {
    return '''
<h1>Privacy Policy</h1>
<p><strong>Last Updated:</strong> January 2024</p>

<h2>1. Information We Collect</h2>
<p>At EKiraya, we collect information that you provide directly to us when using our platform:</p>
<ul>
<li><strong>Business Information:</strong> Business name, GST number, address, phone number, email address</li>
<li><strong>Customer Information:</strong> Name, phone number, driving license details, verification records</li>
<li><strong>Transaction Information:</strong> Wallet transactions, verification fees, payment history</li>
<li><strong>Technical Data:</strong> IP address, browser type, device information, access times</li>
</ul>

<h2>2. How We Use Your Information</h2>
<p>We use your information for the following purposes:</p>
<ul>
<li>Process driving license verifications through Cashfree API</li>
<li>Generate and store digital rental agreements</li>
<li>Manage wallet balance and track transactions</li>
<li>Provide customer support and improve our services</li>
<li>Comply with legal and regulatory requirements</li>
</ul>

<h2>3. Data Security</h2>
<p>We implement industry-standard security measures to protect your data:</p>
<ul>
<li>Encryption of sensitive data at rest and in transit</li>
<li>Secure API calls with authentication tokens</li>
<li>Regular security audits and vulnerability assessments</li>
<li>Access controls and role-based permissions</li>
</ul>

<h2>4. Third-Party Services</h2>
<p>We use trusted third-party services:</p>
<ul>
<li><strong>Cashfree:</strong> For payment processing and DL verification</li>
<li><strong>Cloud Storage:</strong> For secure document storage</li>
<li><strong>Analytics:</strong> To improve platform performance</li>
</ul>

<h2>5. Data Retention</h2>
<p>We retain your data as long as your account is active or as needed to provide services. You may request deletion of your data by contacting support.</p>

<h2>6. Your Rights</h2>
<p>You have the right to:</p>
<ul>
<li>Access and update your business information</li>
<li>Request deletion of your data</li>
<li>Export your data in machine-readable format</li>
<li>Opt-out of marketing communications</li>
</ul>

<h2>7. Cookies</h2>
<p>We use cookies to enhance your experience. You can control cookie settings through your browser preferences.</p>

<h2>8. Changes to This Policy</h2>
<p>We may update this privacy policy from time to time. We will notify you of any material changes via email or platform notification.</p>

<h2>9. Contact Us</h2>
<p>If you have questions about this Privacy Policy, contact us at:</p>
<ul>
<li>Email: <strong>privacy@ekiraya.com</strong></li>
<li>Phone: <strong>+91 98765 43210</strong></li>
<li>Address: Bhubaneswar, Odisha, India</li>
</ul>
''';
  }
  
  String _getTermsOfServiceHtml() {
    return '''
<h1>Terms of Service</h1>
<p><strong>Last Updated:</strong> January 2024</p>

<h2>1. Acceptance of Terms</h2>
<p>By using EKiraya, you agree to these Terms.</p>

<h2>2. Description of Service</h2>
<p>EKiraya provides vehicle rental management platform for:</p>
<ul>
<li>Vehicle fleet management</li>
<li>Customer verification</li>
<li>Digital payments</li>
<li>Rental agreements</li>
<li>Analytics and reports</li>
</ul>

<h2>3. Eligibility</h2>
<p>You must be 18+ years old and have valid business registration.</p>

<h2>4. Account Responsibilities</h2>
<p>You are responsible for:</p>
<ul>
<li>Account security</li>
<li>Information accuracy</li>
<li>All account activities</li>
</ul>

<h2>5. Vehicle Listings</h2>
<p>You agree to:</p>
<ul>
<li>Provide accurate vehicle information</li>
<li>Set appropriate rates</li>
<li>Maintain vehicles properly</li>
<li>Comply with regulations</li>
</ul>

<h2>6. Rental Process</h2>
<ul>
<li>Verify customer licenses</li>
<li>Collect required documents</li>
<li>Generate signed agreements</li>
<li>Document vehicle condition</li>
<li>Process returns and damages</li>
</ul>

<h2>7. Payments and Fees</h2>
<ul>
<li>All transactions via digital wallet</li>
<li>Verification fees apply</li>
<li>Platform fees may apply</li>
<li>Withdrawals subject to processing</li>
</ul>

<h2>8. Prohibited Activities</h2>
<p>You may not:</p>
<ul>
<li>Use platform illegally</li>
<li>Manipulate ratings</li>
<li>Rent without documentation</li>
<li>Share accounts</li>
<li>Bypass security</li>
</ul>

<h2>9. Termination</h2>
<p>We may suspend accounts for violations.</p>

<h2>10. Contact</h2>
<p>Email: legal@ekiraya.com</p>
''';
  }
  
  String _getAboutHtml() {
    return '''
<h1>About EKiraya</h1>

<h2>Our Mission</h2>
<p>Empowering rental businesses with smart technology.</p>

<h2>Why Choose EKiraya?</h2>
<ul>
<li><strong>Secure Document Management</strong> - Digital storage of customer documents</li>
<li><strong>Integrated Wallet System</strong> - Easy payment collection</li>
<li><strong>Automated Documentation</strong> - Digital rental agreements</li>
<li><strong>Business Analytics</strong> - Real-time earnings tracking</li>
</ul>

<h2>Our Features</h2>
<h3>For Shop Owners:</h3>
<ul>
<li>Vehicle Management</li>
<li>Customer Verification</li>
<li>Rental Management</li>
<li>Wallet System</li>
<li>Reports & Analytics</li>
<li>Notifications</li>
</ul>

<h2>Technology Stack</h2>
<ul>
<li><strong>Frontend:</strong> Flutter</li>
<li><strong>Backend:</strong> Laravel API</li>
<li><strong>Database:</strong> MySQL</li>
<li><strong>Payments:</strong> Cashfree</li>
</ul>

<h2>Contact Us</h2>
<p>Email: support@ekiraya.com<br/>Phone: +91 9876543210</p>

<p><strong>© 2024 EKiraya. All rights reserved.</strong></p>
''';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.grey.shade900,
        actions: [
          if (!_isFromApi && _errorMessage.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadContent,
              tooltip: 'Retry from server',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.grey))
          : Column(
              children: [
                // API Status Indicator (only shown when using fallback)
                if (!_isFromApi)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Showing cached content. Connect to internet for latest updates.',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadContent,
                          child: const Text('Retry', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                
                // Last updated info
                if (_lastUpdated.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.update, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'Last Updated: ${_formatDate(_lastUpdated)}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        if (_version.isNotEmpty)
                          Text(
                            '  |  Version $_version',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Content - Renders HTML properly
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _content.isNotEmpty
                        ? Html(
                            data: _content,
                            style: {
                              'h1': Style(
                                fontSize: FontSize(24),
                                fontWeight: FontWeight.bold,
                                margin: Margins.only(bottom: 12, top: 20),
                                color: Colors.black87,
                              ),
                              'h2': Style(
                                fontSize: FontSize(20),
                                fontWeight: FontWeight.w600,
                                margin: Margins.only(bottom: 10, top: 16),
                                color: Colors.black87,
                              ),
                              'h3': Style(
                                fontSize: FontSize(18),
                                fontWeight: FontWeight.w600,
                                margin: Margins.only(bottom: 8, top: 12),
                                color: Colors.black87,
                              ),
                              'p': Style(
                                fontSize: FontSize(14),
                                lineHeight: LineHeight(1.6),
                                margin: Margins.only(bottom: 12),
                                color: Colors.grey.shade800,
                              ),
                              'ul': Style(
                                margin: Margins.only(bottom: 12, left: 20),
                              ),
                              'li': Style(
                                fontSize: FontSize(14),
                                lineHeight: LineHeight(1.5),
                                margin: Margins.only(bottom: 6),
                                color: Colors.grey.shade800,
                              ),
                              'strong': Style(
                                fontWeight: FontWeight.bold,
                              ),
                              'a': Style(
                                color: Colors.blue,
                                textDecoration: TextDecoration.underline,
                              ),
                            },
                            onLinkTap: (url, attributes, element) {
                              if (url != null) {
                                debugPrint('Link tapped: $url');
                                // You can add URL launcher here if needed
                              }
                            },
                          )
                        : Center(
                            child: Text(
                              'No content available',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
  
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day} ${_getMonthName(date.month)} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }
  
  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}