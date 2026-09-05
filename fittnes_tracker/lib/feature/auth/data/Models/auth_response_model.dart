class AuthResponseModel {
  /// The server's stable id for this user — unlike [username], this never
  /// changes for the account, so it's what a third party (RevenueCat's
  /// `appUserID`, for one) must be given instead. Empty only for a session
  /// restored from a cache written before this field existed; the next
  /// silent token refresh overwrites that cache with a response that has it.
  final String id;

  final String token;

  final DateTime expiration;

  final String refreshToken;

  final String username;

  final String email;

  final String firstName;

  final String lastName;

  final DateTime dateOfBirth;

  AuthResponseModel({
    required this.id,
    required this.token,
    required this.expiration,
    required this.refreshToken,
    required this.username,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      id: json['id'] as String? ?? '',
      token: json['token'],
      expiration: DateTime.parse(json['expiration']),
      refreshToken: json['refreshToken'] ?? '',
      username: json['username'],
      email: json['email'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      dateOfBirth: DateTime.parse(json['dateOfBirth']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'token': token,
        'expiration': expiration.toIso8601String(),
        'refreshToken': refreshToken,
        'username': username,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'dateOfBirth': dateOfBirth.toIso8601String(),
      };
}
