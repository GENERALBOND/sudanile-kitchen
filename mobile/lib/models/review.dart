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
      rating: json['rating'],
      comment: json['comment'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}
