import 'dart:collection';
import 'package:shared_preferences/shared_preferences.dart';

class CacheEntry<T> {
  final T data;
  final DateTime cachedAt;
  final Duration ttl;

  CacheEntry(this.data, {Duration? ttl})
      : cachedAt = DateTime.now(),
        ttl = ttl ?? const Duration(minutes: 15);

  bool get isValid => DateTime.now().difference(cachedAt) < ttl;
}

class CacheManager {
  static final CacheManager instance = CacheManager._();
  CacheManager._();

  final Map<String, CacheEntry<dynamic>> _memoryCache = HashMap();
  final Set<String> _prefetchKeys = {};

  static const _prefsPrefix = 'cache_ts_';

  void put<T>(String key, T data, {Duration? ttl}) {
    _memoryCache[key] = CacheEntry<T>(data, ttl: ttl);
  }

  T? get<T>(String key) {
    final entry = _memoryCache[key];
    if (entry == null) return null;
    if (!entry.isValid) {
      _memoryCache.remove(key);
      return null;
    }
    return entry.data as T?;
  }

  bool has(String key) {
    final entry = _memoryCache[key];
    return entry != null && entry.isValid;
  }

  void invalidate(String key) {
    _memoryCache.remove(key);
  }

  void invalidateByPrefix(String prefix) {
    _memoryCache.removeWhere((k, _) => k.startsWith(prefix));
  }

  void clear() {
    _memoryCache.clear();
  }

  Future<void> setLastFetch(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefsPrefix$key', DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> shouldFetch(String key, {Duration minInterval = const Duration(minutes: 5)}) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('$_prefsPrefix$key');
    if (last == null) return true;
    return DateTime.now().millisecondsSinceEpoch - last > minInterval.inMilliseconds;
  }

  void markPrefetched(String key) {
    _prefetchKeys.add(key);
  }

  bool isPrefetched(String key) => _prefetchKeys.contains(key);

  void clearPrefetch() {
    _prefetchKeys.clear();
  }

  Future<void> preloadData(String key, Future<dynamic> Function() fetcher, {Duration? ttl}) async {
    if (has(key)) return;
    try {
      final data = await fetcher();
      put(key, data, ttl: ttl);
      markPrefetched(key);
    } catch (_) {}
  }

  Future<T> getOrFetch<T>(String key, Future<T> Function() fetcher, {Duration? ttl}) async {
    final cached = get<T>(key);
    if (cached != null) return cached;
    final data = await fetcher();
    put(key, data, ttl: ttl);
    return data;
  }
}
