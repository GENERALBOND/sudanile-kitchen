/// Meal options for recipes, mirroring the backend `MEAL_TYPES` choices.
class MealTypeOption {
  final String key;
  final String label;

  const MealTypeOption(this.key, this.label);
}

const List<MealTypeOption> mealTypeOptions = [
  MealTypeOption('breakfast', 'Breakfast'),
  MealTypeOption('lunch', 'Lunch'),
  MealTypeOption('dinner', 'Dinner / Supper'),
  MealTypeOption('any', 'Any time'),
];

/// "Any time" cannot be combined with a specific meal.
const String anyTimeKey = 'any';

String? mealLabel(String key) {
  for (final option in mealTypeOptions) {
    if (option.key == key) return option.label;
  }
  return null;
}