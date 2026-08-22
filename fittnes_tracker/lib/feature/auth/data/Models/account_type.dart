/// What kind of account to create at sign-up.
///
/// This is the only moment the choice exists. Registering as [trainer]
/// provisions the trainer licence that unlocks the Trainer Console; an existing
/// account can't be converted, and nothing in the trainee app offers to.
enum AccountType {
  trainee,
  trainer;

  /// The value the API expects. Matches the C# `AccountType` enum member names,
  /// which ASP.NET binds case-insensitively.
  String get wireName => name;
}
