class RecipeSubmission {
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
  final List<String> mealTypes;
  final String mealTypesDisplay;
  final String status;
  final String adminNotes;
  final DateTime submittedAt;
  final DateTime? reviewedAt;

  RecipeSubmission({
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
    this.mealTypes = const [],
    this.mealTypesDisplay = '',
    required this.status,
    this.adminNotes = '',
    required this.submittedAt,
    this.reviewedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  int get totalMinutes {
    final totalSeconds = (prepHours * 3600) +
        (prepMinutes * 60) +
        prepSeconds +
        (cookHours * 3600) +
        (cookMinutes * 60) +
        cookSeconds;
    return (totalSeconds / 60).ceil();
  }

  String get totalTimeDisplay {
    final minutes = totalMinutes;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final rem = minutes % 60;
      return rem > 0 ? '${hours}h ${rem}m' : '${hours}h';
    }
    return '${minutes}m';
  }

  factory RecipeSubmission.fromJson(Map<String, dynamic> json) {
    return RecipeSubmission(
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
      mealTypes: (json['meal_types'] as List<dynamic>? ?? [])
          .map((m) => m.toString())
          .toList(),
      mealTypesDisplay: json['meal_types_display'] ?? '',
      status: json['status'] ?? 'pending',
      adminNotes: json['admin_notes'] ?? '',
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'])
          : DateTime.now(),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'])
          : null,
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
        'meal_types': mealTypes,
        'meal_types_display': mealTypesDisplay,
        'status': status,
        'admin_notes': adminNotes,
        'submitted_at': submittedAt.toIso8601String(),
        'reviewed_at': reviewedAt?.toIso8601String(),
      };
}