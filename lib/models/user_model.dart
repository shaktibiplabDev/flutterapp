class User {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? avatar;
  final String? role;
  final bool isEmailVerified;
  final bool hasPassword;
  final bool isGoogleUser;
  int walletBalance;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool needsPasswordSetup;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatar,
    this.role,
    required this.isEmailVerified,
    required this.hasPassword,
    required this.isGoogleUser,
    required this.walletBalance,
    required this.createdAt,
    required this.updatedAt,
    this.needsPasswordSetup = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse int
    int parseBalance(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    // Helper function to safely parse DateTime
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return User(
      id: json['id'] is int ? json['id'] : (json['id'] as int?) ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
      avatar: json['avatar']?.toString(),
      role: json['role']?.toString() ?? 'user',
      isEmailVerified: json['is_email_verified'] == true || json['email_verified'] == true,
      hasPassword: json['has_password'] == true,
      isGoogleUser: json['is_google_user'] == true,
      walletBalance: parseBalance(json['wallet_balance']),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      needsPasswordSetup: json['needs_password_setup'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'avatar': avatar,
      'role': role,
      'is_email_verified': isEmailVerified,
      'has_password': hasPassword,
      'is_google_user': isGoogleUser,
      'wallet_balance': walletBalance,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'needs_password_setup': needsPasswordSetup,
    };
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? avatar,
    String? role,
    bool? isEmailVerified,
    bool? hasPassword,
    bool? isGoogleUser,
    int? walletBalance,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? needsPasswordSetup,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      role: role ?? this.role,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      hasPassword: hasPassword ?? this.hasPassword,
      isGoogleUser: isGoogleUser ?? this.isGoogleUser,
      walletBalance: walletBalance ?? this.walletBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      needsPasswordSetup: needsPasswordSetup ?? this.needsPasswordSetup,
    );
  }
}