class AuthResponseModel {
  final String token;

  final DateTime expiration;

  final String username;

  final String email;

  final String firstName;

  final String lastName;

  final DateTime dateOfBirth;

  AuthResponseModel({
    required this.token,
    required this.expiration,
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
      username: json['username'],
      email: json['email'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      dateOfBirth: DateTime.parse(json['dateOfBirth']),
    );
  }
}
