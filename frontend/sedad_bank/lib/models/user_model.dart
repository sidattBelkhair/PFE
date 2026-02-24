class UserModel {
  final String id;
  final String username;
  final String email;
  final String firstName;
  final String lastName;
  final String? phoneNumber;
  final String? profilePhoto;
  final String role;
  final String status;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phoneNumber,
    this.profilePhoto,
    required this.role,
    required this.status,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      phoneNumber: json['phone_number'],
      profilePhoto: json['profile_photo'],
      role: json['role'] ?? 'client',
      status: json['status'] ?? 'active',
    );
  }

  String getFullName() => '$firstName $lastName';
}