class Category {
  final int id;
  final String name;
  final String? description;
  final String? icon;

  Category({
    required this.id,
    required this.name,
    this.description,
    this.icon,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      icon: json['icon'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon,
      };
}

class Recipe {
  final int id;
  final String title;
  final String description;
  final List<dynamic> ingredients;
  final List<dynamic> instructions;
  final String culturalInfo;
  final int prepHours;
  final int prepMinutes;
  final int prepSeconds;
  final int cookHours;
  final int cookMinutes;
  final int cookSeconds;
  final int servings;
  final String difficulty;
  final String? imageUrl;
  final String categoryName;
  final String authorName;
  final List<String> mealTypes;
  final String mealTypesDisplay;
  final double averageRating;
  final int totalReviews;
  final int viewCount;
  final DateTime createdAt;

  Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.ingredients,
    required this.instructions,
    required this.culturalInfo,
    required this.prepHours,
    required this.prepMinutes,
    required this.prepSeconds,
    required this.cookHours,
    required this.cookMinutes,
    required this.cookSeconds,
    required this.servings,
    required this.difficulty,
    this.imageUrl,
    required this.categoryName,
    required this.authorName,
    this.mealTypes = const [],
    this.mealTypesDisplay = '',
    required this.averageRating,
    required this.totalReviews,
    required this.viewCount,
    required this.createdAt,
  });

  bool get isAnyTime => mealTypes.isEmpty || mealTypes.contains('any');

  int get totalTime {
    int totalSeconds = (prepHours * 3600) + (prepMinutes * 60) + prepSeconds +
                       (cookHours * 3600) + (cookMinutes * 60) + cookSeconds;
    return (totalSeconds / 60).ceil();
  }

  // Add this getter for display
  String get totalTimeDisplay {
    int totalMinutes = totalTime;
    if (totalMinutes >= 60) {
      int hours = totalMinutes ~/ 60;
      int minutes = totalMinutes % 60;
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      }
      return '${hours}h';
    }
    return '${totalMinutes}m';
  }

  String get preparationTimeDisplay {
    List<String> parts = [];
    if (prepHours > 0) parts.add("$prepHours hr${prepHours > 1 ? 's' : ''}");
    if (prepMinutes > 0) parts.add("$prepMinutes min${prepMinutes > 1 ? 's' : ''}");
    if (prepSeconds > 0) parts.add("$prepSeconds sec${prepSeconds > 1 ? 's' : ''}");
    return parts.isEmpty ? "0 mins" : parts.join(" ");
  }

  String get cookingTimeDisplay {
    List<String> parts = [];
    if (cookHours > 0) parts.add("$cookHours hr${cookHours > 1 ? 's' : ''}");
    if (cookMinutes > 0) parts.add("$cookMinutes min${cookMinutes > 1 ? 's' : ''}");
    if (cookSeconds > 0) parts.add("$cookSeconds sec${cookSeconds > 1 ? 's' : ''}");
    return parts.isEmpty ? "0 mins" : parts.join(" ");
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      ingredients: json['ingredients'] ?? [],
      instructions: json['instructions'] ?? [],
      culturalInfo: json['cultural_info'] ?? '',
      prepHours: json['prep_hours'] ?? 0,
      prepMinutes: json['prep_minutes'] ?? 0,
      prepSeconds: json['prep_seconds'] ?? 0,
      cookHours: json['cook_hours'] ?? 0,
      cookMinutes: json['cook_minutes'] ?? 0,
      cookSeconds: json['cook_seconds'] ?? 0,
      servings: json['servings'] ?? 4,
      difficulty: json['difficulty'] ?? 'medium',
      imageUrl: json['image_url'],
      categoryName: json['category_name'] ?? '',
      authorName: json['author_name'] ?? '',
      mealTypes: (json['meal_types'] as List<dynamic>? ?? [])
          .map((m) => m.toString())
          .toList(),
      mealTypesDisplay: json['meal_types_display'] ?? '',
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: json['total_reviews'] ?? 0,
      viewCount: json['view_count'] ?? 0,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'ingredients': ingredients,
        'instructions': instructions,
        'cultural_info': culturalInfo,
        'prep_hours': prepHours,
        'prep_minutes': prepMinutes,
        'prep_seconds': prepSeconds,
        'cook_hours': cookHours,
        'cook_minutes': cookMinutes,
        'cook_seconds': cookSeconds,
        'servings': servings,
        'difficulty': difficulty,
        'image_url': imageUrl,
        'category_name': categoryName,
        'author_name': authorName,
        'meal_types': mealTypes,
        'meal_types_display': mealTypesDisplay,
        'average_rating': averageRating,
        'total_reviews': totalReviews,
        'view_count': viewCount,
        'created_at': createdAt.toIso8601String(),
      };
}
