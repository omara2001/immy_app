class UserProfile {
  final String id;
  final String name;
  final String email;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
  });

  // Convert to and from JSON for storage
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
    };
  }
}
