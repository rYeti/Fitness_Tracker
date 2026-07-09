class AuthResponseModel {
  final String token;

  final DateTime expiration;

  final String refreshToken;

  final String username;

  final String email;

  final String firstName;

  final String lastName;

  final DateTime dateOfBirth;

  AuthResponseModel({
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
