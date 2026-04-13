class User {
  final int id;
  final String name;
  final String email;
  final String phone;
  final bool emailVerified;  // Changed from emailVerifiedAt
  final String? googleId;
  final String? avatar;
  final String role;
  final int walletBalance;
  final bool isGoogleUser;
  final bool hasPassword;
  final bool needsPasswordSetup;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  User({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.emailVerified,  // Changed
    this.googleId,
    this.avatar,
    this.role = 'user',
    this.walletBalance = 0,
    this.isGoogleUser = false,
    this.hasPassword = true,
    this.needsPasswordSetup = false,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'] ?? '',
      emailVerified: json['email_verified'] ?? false,  // Changed to email_verified
      googleId: json['google_id'],
      avatar: json['avatar'],
      role: json['role'] ?? 'user',
      walletBalance: json['wallet_balance'] ?? 0,
      isGoogleUser: json['is_google_user'] ?? false,
      hasPassword: json['has_password'] ?? true,
      needsPasswordSetup: json['needs_password_setup'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
  
  bool get isEmailVerified => emailVerified;  // Simplified
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'email_verified': emailVerified,  // Changed
      'google_id': googleId,
      'avatar': avatar,
      'role': role,
      'wallet_balance': walletBalance,
      'is_google_user': isGoogleUser,
      'has_password': hasPassword,
      'needs_password_setup': needsPasswordSetup,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}