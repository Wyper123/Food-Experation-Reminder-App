class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.accountType,
    this.householdId,
  });

  final String id;
  final String name;
  final String email;
  final String accountType;
  final String? householdId;

  UserModel copyWith({String? name, String? accountType}) => UserModel(
        id: id,
        name: name ?? this.name,
        email: email,
        accountType: accountType ?? this.accountType,
        householdId: householdId,
      );

  String get initials => name
      .trim()
      .split(' ')
      .where((p) => p.isNotEmpty)
      .map((p) => p[0])
      .take(2)
      .join()
      .toUpperCase();

  /// `password_hash` is written by UserDao and never loaded into the model.
  /// `household_id` comes from a join on household_members.
  factory UserModel.fromMap(Map<String, Object?> map) => UserModel(
        id: map['id']! as String,
        name: map['name']! as String,
        email: map['email']! as String,
        accountType: map['account_type']! as String,
        householdId: map['household_id'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'account_type': accountType,
      };

  /// Demo account inserted by DevSeeder on first launch.
  static const UserModel mock = UserModel(
    id: 'u1',
    name: 'Alex Rivera',
    email: 'alex.rivera@email.com',
    accountType: 'Student',
    householdId: 'H-4B27',
  );
}
