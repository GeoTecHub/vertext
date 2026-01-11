class UserResponse {
  final String token;
  final User user;
  UserResponse({required this.token, required this.user});

  factory UserResponse.fromJson(Map<String, dynamic> j) =>
      UserResponse(token: j['token'], user: User.fromJson(j['user']));
}

class User {
  final int id;
  final String username;
  final String email;
  final String userType;
  final bool isActive;
  final String firstName;
  final String lastName;
  final String displayName;
  final String licenseNumber;
  final String? mobile;
  final String? address;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.userType,
    required this.isActive,
    required this.firstName,
    required this.lastName,
    required this.displayName,
    required this.licenseNumber,
    this.mobile,
    this.address,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'],
    username: j['username'],
    email: j['email'],
    userType: j['user_type'],
    isActive: j['is_active'],
    firstName: j['first_name'],
    lastName: j['last_name'],
    displayName: j['display_name'],
    licenseNumber: j['license_number'],
    mobile: j['mobile'],
    address: j['address'],
  );
}
