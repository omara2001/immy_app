class UserProfile {
  final String id;
  final String name;
  final String email;
  bool isAdmin;
  String? passwordHash; // Make passwordHash optional with nullable type

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.isAdmin = false,
    this.passwordHash, // Optional parameter
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'isAdmin': isAdmin,
      'passwordHash': passwordHash,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      isAdmin: json['isAdmin'] ?? false,
      passwordHash: json['passwordHash'],
    );
  }
}
