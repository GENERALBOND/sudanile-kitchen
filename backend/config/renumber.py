from django.db import connection


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