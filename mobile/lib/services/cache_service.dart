import 'dart:developer';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// Persistent disk cache built on Hive (Community Edition).
///
/// Stores raw model JSON so the app can render fully offline:
///   * list entries (`writeList`/`readList`) — keyed collections such as
///     "recipes for query X page N", categories, favorites, reviews.
///   * detail entries (`writeJson`/`readJson`) — single objects keyed by id
///     (recipe detail, community post detail) so screens opened from a
///     push/other deep link work offline too.
///
/// Reads only ever serve a fallback when the network request failed, so no
/// TTL is applied on reads by default — offline content is always shown.
/// TTL logic is available via [ttl] for callers that want it.
class CacheService {
  CacheService._();

  static final CacheService instance = CacheService._();

  static const String _boxName = 'app_cache';

  Box<dynamic>? _box;
  bool _initialized = false;

  bool get isReady => _initialized && _box != null;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox<dynamic>(_boxName);
      _initialized = true;
      log('🗄️ Cache initialised');
    } catch (e) {
      // Cache must never block app startup: on failure the app simply runs
      // without offline support.
      log('❌ Cache init failed: $e');
    }
  }

  String _listKey(String collection, String? key) =>
      '$collection:list:${key ?? 'default'}';

  String _detailKey(String collection, int id) =>
      '$collection:detail:$id';

  /// Stores a list of JSON maps under `collection` (optional `key` for
  /// per-query entries). On success the server data is always written so the
  /// freshest snapshot is available for offline use.
  Future<void> writeList(
    String collection,
    List<dynamic> data, {
    String? key,
  }) async {
    if (!isReady) return;
    try {
      await _box!.put(_listKey(collection, key), {
        'data': data,
        'updated': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      log('❌ Cache write failed ($collection): $e');
    }
  }

  /// Reads a previously stored list. Returns `null` when absent (or, if a
  /// [ttl] is supplied and the entry is older than it, when [ignoreTtl] is
  /// false).
  List<dynamic>? readList(
    String collection, {
    String? key,
    Duration? ttl,
    bool ignoreTtl = true,
  }) {
    if (!isReady) return null;
    final entry = _box!.get(_listKey(collection, key));
    if (entry is! Map) return null;
    final data = entry['data'];
    if (data is! List) return null;
    if (!ignoreTtl && ttl != null) {
      final updated = entry['updated'];
      if (updated is int &&
          DateTime.now().millisecondsSinceEpoch - updated > ttl.inMilliseconds) {
        return null;
      }
    }
    return data;
  }

  /// Deletes a stored list (e.g. to invalidate a stale review cache after a
  /// successful write).
  Future<void> removeList(String collection, {String? key}) async {
    if (!isReady) return;
    try {
      await _box!.delete(_listKey(collection, key));
    } catch (e) {
      log('❌ Cache delete failed ($collection): $e');
    }
  }

  /// Stores a single object's JSON under `collection` keyed by `id`.
  Future<void> writeJson(
    String collection,
    int id,
    Map<String, dynamic> json,
  ) async {
    if (!isReady) return;
    try {
      await _box!.put(_detailKey(collection, id), json);
    } catch (e) {
      log('❌ Cache write failed ($collection/$id): $e');
    }
  }

  Map<String, dynamic>? readJson(String collection, int id) {
    if (!isReady) return null;
    final value = _box!.get(_detailKey(collection, id));
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  /// Wipes the whole cache — called on logout/account deletion so one user's
  /// favorites/community data never leaks into the next session.
  Future<void> clearAll() async {
    if (!isReady) return;
    try {
      await _box!.clear();
      log('🧹 Disk cache cleared');
    } catch (e) {
      log('❌ Cache clear failed: $e');
    }
  }
}
