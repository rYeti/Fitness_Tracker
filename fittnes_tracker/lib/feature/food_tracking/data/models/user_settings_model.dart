class UserSettings {
  final double dailyCalorieGoal;

  UserSettings({required this.dailyCalorieGoal});

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(dailyCalorieGoal: json['dailyCalorieGoal']);
  }

  Map<String, dynamic> toJson() {
    return {'dailyCalorieGoal': dailyCalorieGoal};
  }
}
