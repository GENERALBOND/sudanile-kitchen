from django.core.exceptions import ValidationError

# Meals at which a recipe is normally eaten. A recipe may be tagged for one or
# more of breakfast/lunch/dinner; "any" means it has no specific meal and is
# mutually exclusive with the others. An empty list also means "any time".
MEAL_TYPES = [
    ('breakfast', 'Breakfast'),
    ('lunch', 'Lunch'),
    ('dinner', 'Dinner / Supper'),
    ('any', 'Any time'),
]

MEAL_TYPE_KEYS = [key for key, _ in MEAL_TYPES]
MEAL_TYPE_LABELS = dict(MEAL_TYPES)


def clean_meal_types(value):
    """Validate and normalize a meal_types value.

    Returns a de-duplicated list of valid keys. ``None`` becomes ``[]``.
    Raises ``ValidationError`` for unknown keys or when ``any`` is combined
    with a specific meal.
    """
    if value is None:
        return []
    if not isinstance(value, (list, tuple)):
        raise ValidationError('Meal types must be a list.')
    cleaned = []
    for item in value:
        if item not in MEAL_TYPE_KEYS:
            raise ValidationError(f'"{item}" is not a valid meal type.')
        if item not in cleaned:
            cleaned.append(item)
    if 'any' in cleaned and len(cleaned) > 1:
        raise ValidationError('"Any time" cannot be combined with other meal types.')
    return cleaned


def meal_types_display(value):
    """Human-readable label for a stored meal_types list."""
    if not value:
        return 'Any time'
    labels = []
    for key in value:
        if key == 'any':
            return 'Any time'
        labels.append(MEAL_TYPE_LABELS.get(key, key))
    return ', '.join(labels) if labels else 'Any time'
