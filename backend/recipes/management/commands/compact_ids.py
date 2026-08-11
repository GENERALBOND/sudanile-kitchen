from django.core.management.base import BaseCommand
from django.db import connection, transaction

from config.renumber import sync_sequence
from favorites.models import Favorite
from recipes.models import Category, Recipe
from reviews.models import Review
from submissions.models import RecipeSubmission

# Offset used to move every id out of the way before assigning the final
# sequential values, so nothing collides mid-renumber.
TEMP_OFFSET = 10 ** 12

TABLES = [
    Recipe,
    Category,
    Review,
    RecipeSubmission,
]

# (referrer model, fk column, model whose ids the column points to)
REFERENCES = [
    (Review, 'recipe_id', Recipe),
    (Favorite, 'recipe_id', Recipe),
    (Recipe, 'category_id', Category),
]


class Command(BaseCommand):
    help = (
        'Compress the auto-increment ids of recipes, categories, reviews and '
        'submissions so numbering has no gaps, preserving foreign keys.'
    )

    def handle(self, *args, **options):
        cursor = connection.cursor()
        try:
            cursor.execute('PRAGMA foreign_keys = OFF')
            with transaction.atomic():
                mappings = {}
                for model in TABLES:
                    table = model._meta.db_table
                    cursor.execute(f'SELECT id FROM {table} ORDER BY id')
                    ids = [row[0] for row in cursor.fetchall()]
                    mapping = {old: new for new, old in enumerate(ids, start=1)}
                    mappings[model] = mapping

                    for old in ids:
                        cursor.execute(
                            f'UPDATE {table} SET id = %s WHERE id = %s',
                            [old + TEMP_OFFSET, old],
                        )

                for model, mapping in mappings.items():
                    table = model._meta.db_table
                    for old, new in mapping.items():
                        cursor.execute(
                            f'UPDATE {table} SET id = %s WHERE id = %s',
                            [new, old + TEMP_OFFSET],
                        )

                for referrer, column, target in REFERENCES:
                    mapping = mappings[target]
                    table = referrer._meta.db_table
                    for old, new in mapping.items():
                        if old != new:
                            cursor.execute(
                                f'UPDATE {table} SET {column} = %s '
                                f'WHERE {column} = %s',
                                [new, old],
                            )

                for model in TABLES:
                    sync_sequence(model)

            self.stdout.write(self.style.SUCCESS('Successfully compressed ids.'))
        finally:
            cursor.execute('PRAGMA foreign_keys = ON')
            cursor.close()