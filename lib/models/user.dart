class User {
  final int id;
  final String name;
  final String email;
  final String token;
  final bool isAdmin;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.token,
    this.isAdmin = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is String ? int.parse(json['id']) : json['id'],
      name: json['name'],
      email: json['email'],
      token: json['token'],
      isAdmin: json['isAdmin'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'token': token,
      'isAdmin': isAdmin,
    };
  }
}
