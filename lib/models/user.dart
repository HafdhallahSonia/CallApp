// models/user.dart
class User {
  final int? id;
  final String username;
  final String passwordHash;
  final String? photoPath;

  User({
    this.id, 
    required this.username, 
    required this.passwordHash,
    this.photoPath,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'username': username,
    'passwordHash': passwordHash,
    'photo': photoPath,
  };

  factory User.fromMap(Map<String, dynamic> map) => User(
    id: map['id'],
    username: map['username'],
    passwordHash: map['passwordHash'],
    photoPath: map['photo'],
  );
}
