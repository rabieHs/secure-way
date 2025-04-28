// lib/models/user_model.dart

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String userType;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.userType,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      userType: json['userType'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'userType': userType,
    };
  }
}
