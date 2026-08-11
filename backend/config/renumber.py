from django.db import connection


def lowest_free_id(sender):
    """Return the smallest positive integer not currently used as a pk.

    New rows are assigned this value so that deleting an item never leaves a
    permanent gap in the displayed numbering (e.g. deleting ID 1 means the
    next created item is numbered 1 again).
    """
    ids = set(sender.objects.values_list('id', flat=True))
    candidate = 1
    while candidate in ids:
        candidate += 1
    return candidate


def sync_sequence(sender):
    """Keep SQLite's auto-increment sequence aligned with the highest pk.

    Manually assigning low pks does not move SQLite's sequence, so we sync it
    after each save to prevent any future plain auto-insert from reusing one
    of the ids we handed out.
    """
    if connection.vendor != 'sqlite':
        return
    table = sender._meta.db_table
    column = sender._meta.pk.column
    with connection.cursor() as cursor:
        cursor.execute(f'SELECT COALESCE(MAX({column}), 0) FROM {table}')
        max_id = cursor.fetchone()[0]
        cursor.execute(
            'INSERT OR REPLACE INTO sqlite_sequence (name, seq) VALUES (%s, %s)',
            [table, max_id],
        )