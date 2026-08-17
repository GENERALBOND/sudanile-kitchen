class User {
  final int id;
  final String username;
  final String email;
  final String role;
  final bool isStaff;
  final bool isSuperuser;
  final String? profilePicture;
  final String? bio;
  final DateTime createdAt;
  final int favoritesCount;
  final int reviewsCount;
  final int submissionsCount;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.isStaff = false,
    this.isSuperuser = false,
    this.profilePicture,
    this.bio,
    required this.createdAt,
    this.favoritesCount = 0,
    this.reviewsCount = 0,
    this.submissionsCount = 0,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'member',
      isStaff: json['is_staff'] ?? false,
      isSuperuser: json['is_superuser'] ?? false,
      profilePicture: json['profile_picture'],
      bio: json['bio'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      favoritesCount: json['favorites_count'] ?? 0,
      reviewsCount: json['reviews_count'] ?? 0,
      submissionsCount: json['submissions_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role,
      'is_staff': isStaff,
      'is_superuser': isSuperuser,
      'profile_picture': profilePicture,
      'bio': bio,
      'created_at': createdAt.toIso8601String(),
      'favorites_count': favoritesCount,
      'reviews_count': reviewsCount,
      'submissions_count': submissionsCount,
    };
  }
}
