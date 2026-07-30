import re
from difflib import SequenceMatcher
from .models import Recipe


def normalize_title(title):
    title = title.lower().strip()
    title = re.sub(r'\s+', ' ', title)
    title = re.sub(r'[^\w\s]', '', title)
    return title


def find_duplicates(title, ingredients=None, category=None, exclude_id=None):
    normalized = normalize_title(title)
    matches = []

    queryset = Recipe.objects.filter(is_published=True)
    if exclude_id:
        queryset = queryset.exclude(pk=exclude_id)

    for recipe in queryset:
        recipe_normalized = normalize_title(recipe.title)
        ratio = SequenceMatcher(None, normalized, recipe_normalized).ratio()

        if ratio >= 0.85:
            matches.append({
                'recipe': recipe,
                'score': ratio,
                'reason': f'Title matches "{recipe.title}" ({ratio:.0%} similarity)'
            })
            continue

        if ratio >= 0.6 and category and recipe.category == category:
            matches.append({
                'recipe': recipe,
                'score': ratio,
                'reason': f'Similar title in same category: "{recipe.title}" ({ratio:.0%} similarity)'
            })
            continue

        if ratio >= 0.5 and ingredients and recipe.ingredients:
            norm_ingredients = set(i.lower().strip() for i in ingredients if isinstance(i, str))
            recipe_ingredients = set(
                i.lower().strip() for i in recipe.ingredients if isinstance(i, str)
            )
            if norm_ingredients and recipe_ingredients:
                overlap = norm_ingredients & recipe_ingredients
                if len(overlap) >= max(2, len(norm_ingredients) // 2):
                    matches.append({
                        'recipe': recipe,
                        'score': ratio,
                        'reason': f'Similar title and overlapping ingredients with "{recipe.title}" ({ratio:.0%} similarity)'
                    })

    matches.sort(key=lambda m: m['score'], reverse=True)
    return matches
