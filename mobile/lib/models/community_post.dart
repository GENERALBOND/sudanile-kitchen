class CommunityPost {
  final int id;
  final int userId;
  final String userName;
  final String? userProfilePicture;
  final String caption;
  final String? imageUrl;
  final int? recipeId;
  final String? recipeTitle;
  final String? recipeImageUrl;
  final int likeCount;
  final int commentCount;
  final bool isLikedByMe;
  final DateTime createdAt;

  CommunityPost({
    required this.id,
    required this.userId,
    required this.userName,
    this.userProfilePicture,
    required this.caption,
    this.imageUrl,
    this.recipeId,
    this.recipeTitle,
    this.recipeImageUrl,
    required this.likeCount,
    required this.commentCount,
    required this.isLikedByMe,
    required this.createdAt,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    return CommunityPost(
      id: json['id'],
      userId: json['user'] ?? 0,
      userName: json['user_name'] ?? '',
      userProfilePicture: json['user_profile_picture'],
      caption: json['caption'] ?? '',
      imageUrl: json['image_url'],
      recipeId: json['recipe'],
      recipeTitle: json['recipe_title'],
      recipeImageUrl: json['recipe_image_url'],
      likeCount: json['like_count'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
      isLikedByMe: json['is_liked_by_me'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  CommunityPost copyWith({
    int? likeCount,
    int? commentCount,
    bool? isLikedByMe,
  }) {
    return CommunityPost(
      id: id,
      userId: userId,
      userName: userName,
      userProfilePicture: userProfilePicture,
      caption: caption,
      imageUrl: imageUrl,
      recipeId: recipeId,
      recipeTitle: recipeTitle,
      recipeImageUrl: recipeImageUrl,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user': userId,
        'user_name': userName,
        'user_profile_picture': userProfilePicture,
        'caption': caption,
        'image_url': imageUrl,
        'recipe': recipeId,
        'recipe_title': recipeTitle,
        'recipe_image_url': recipeImageUrl,
        'like_count': likeCount,
        'comment_count': commentCount,
        'is_liked_by_me': isLikedByMe,
        'created_at': createdAt.toIso8601String(),
      };
}

class CommunityComment {
  final int id;
  final int userId;
  final String userName;
  final String? userProfilePicture;
  final String comment;
  final DateTime createdAt;

  CommunityComment({
    required this.id,
    required this.userId,
    required this.userName,
    this.userProfilePicture,
    required this.comment,
    required this.createdAt,
  });

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    return CommunityComment(
      id: json['id'],
      userId: json['user'] ?? 0,
      userName: json['user_name'] ?? '',
      userProfilePicture: json['user_profile_picture'],
      comment: json['comment'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user': userId,
        'user_name': userName,
        'user_profile_picture': userProfilePicture,
        'comment': comment,
        'created_at': createdAt.toIso8601String(),
      };
}

/// A member's public profile as returned by
/// `GET /api/users/profile/<id>/` (no private email).
class CommunityMemberProfile {
  final int id;
  final String username;
  final String role;
  final String? profilePicture;
  final String bio;
  final DateTime createdAt;
  final int favoritesCount;
  final int reviewsCount;
  final int submissionsCount;
  final int postCount;
  final int likeCount;
  final int commentCount;

  CommunityMemberProfile({
    required this.id,
    required this.username,
    required this.role,
    this.profilePicture,
    required this.bio,
    required this.createdAt,
    this.favoritesCount = 0,
    this.reviewsCount = 0,
    this.submissionsCount = 0,
    this.postCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  bool get isAdmin => role == 'admin';

  factory CommunityMemberProfile.fromJson(Map<String, dynamic> json) {
    return CommunityMemberProfile(
      id: json['id'],
      username: json['username'] ?? '',
      role: json['role'] ?? 'user',
      profilePicture: json['profile_picture'],
      bio: json['bio'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      favoritesCount: json['favorites_count'] ?? 0,
      reviewsCount: json['reviews_count'] ?? 0,
      submissionsCount: json['submissions_count'] ?? 0,
      postCount: json['post_count'] ?? 0,
      likeCount: json['like_count'] ?? 0,
      commentCount: json['comment_count'] ?? 0,
    );
  }
}
