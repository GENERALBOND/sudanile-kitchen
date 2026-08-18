class Review {
  final int id;
  final int user;
  final String userName;
  final String? userProfilePicture;
  final int recipe;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  Review({
    required this.id,
    required this.user,
    required this.userName,
    this.userProfilePicture,
    required this.recipe,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'],
      user: json['user'],
      userName: json['user_name'] ?? '',
      userProfilePicture: json['user_profile_picture'],
      recipe: json['recipe'],
      rating: json['rating'] ?? 0,
      comment: json['comment'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user': user,
        'user_name': userName,
        'user_profile_picture': userProfilePicture,
        'recipe': recipe,
        'rating': rating,
        'comment': comment,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
