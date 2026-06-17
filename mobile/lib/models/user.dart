class User {
  final int id;
  final String username;
  final String email;
  final String role;
  final String? profilePicture;
  final String? bio;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.profilePicture,
    this.bio,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      role: json['role'],
      profilePicture: json['profile_picture'],
      bio: json['bio'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role,
      'profile_picture': profilePicture,
      'bio': bio,
      'created_at': createdAt.toIso8601String(),
    };
  }
}