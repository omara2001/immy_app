class Child {
  final String id;
  final String name;
  final int? age;
  final String? interests;

  Child({
    required this.id,
    required this.name,
    this.age,
    this.interests,
  });

  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      id: json['id'].toString(),
      name: json['name'],
      age: json['age'] != null ? int.parse(json['age'].toString()) : null,
      interests: json['interests'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'age': age,
      'interests': interests,
    };
  }
}
