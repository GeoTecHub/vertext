class UserResponse {
  final String token;
  final User user;
  UserResponse({required this.token, required this.user});

  factory UserResponse.fromJson(Map<String, dynamic> j) => UserResponse(
        token: j['token'] ?? j['auth_token'] ?? '',
        user: User.fromJson(
            j), // Parse from root since user fields are root level now
      );
}

class User {
  final bool userIsActive;
  final bool organizationIsActive;
  final bool subscriptionIsExpired;

  User({
    required this.userIsActive,
    required this.organizationIsActive,
    required this.subscriptionIsExpired,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        userIsActive: j['user_is_active'] ?? false,
        organizationIsActive: j['organization_is_active'] ?? false,
        subscriptionIsExpired: j['subscription_is_expired'] ?? false,
      );
}
