import 'package:flutter/foundation.dart';

/// Base for controllers whose data belongs to one scope (a household or a
/// user). The shell rebinds them whenever the session changes, so screens
/// never pass IDs around.
///
/// [isLoading] stays true until the first fetch for the current scope
/// finishes; screens show their skeleton while it is true.
abstract class ScopedController<T> extends ChangeNotifier {
  String? _scopeId;
  T? _data;
  bool _isLoading = true;
  Object? _error;

  String? get scopeId => _scopeId;
  bool get isLoading => _isLoading;
  Object? get error => _error;

  @protected
  T? get data => _data;

  @protected
  set data(T? value) {
    _data = value;
    notifyListeners();
  }

  /// Loads the data for [scopeId] from storage.
  @protected
  Future<T> fetch(String scopeId);

  /// Called from a ProxyProvider `update`, i.e. during build, so it must not
  /// notify synchronously.
  void bind(String? scopeId) {
    if (scopeId == _scopeId) return;
    _scopeId = scopeId;
    _data = null;
    _error = null;
    _isLoading = true;
    if (scopeId != null) _load(scopeId);
  }

  /// Re-fetches without going back to the skeleton (pull-to-refresh).
  Future<void> refresh() async {
    final id = _scopeId;
    if (id != null) await _load(id);
  }

  Future<void> _load(String id) async {
    try {
      final result = await fetch(id);
      if (id != _scopeId) return; // Scope changed while loading.
      _data = result;
      _error = null;
    } catch (e, st) {
      if (id != _scopeId) return;
      _error = e;
      debugPrint('$runtimeType failed to load: $e\n$st');
    }
    _isLoading = false;
    notifyListeners();
  }
}
