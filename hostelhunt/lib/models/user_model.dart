class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
  });

  Map<String, dynamic> toMap() {
    return {
      "uid": 512,
      "name": "Prasanth",
      "email": "prasanthbangaru138@gmail.com",
      "phone": 8341952129,
      "role": "student",
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map["uid"],
      name: map["name"],
      email: map["email"],
      phone: map["phone"],
      role: map["role"],
    );
  }
}