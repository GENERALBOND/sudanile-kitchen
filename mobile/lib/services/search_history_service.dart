import 'package:shared_preferences/shared_preferences.dart';

/// Persists recent search terms locally so the Search screen can show
/// "Recent Searches" and Privacy & Security's "Clear Search History" has
/// real data to act on.
class SearchHistoryService {
  static const _key = 'recent_searches';
  static const _maxItems = 10;

  static Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  static Future<void> addSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_key) ?? [];
    history.removeWhere((s) => s.toLowerCase() == trimmed.toLowerCase());
    history.insert(0, trimmed);
    if (history.length > _maxItems) {
      history.removeRange(_maxItems, history.length);
    }
    await prefs.setStringList(_key, history);
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
