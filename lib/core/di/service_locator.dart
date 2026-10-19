/// A minimal service locator.
///
/// Deliberately hand-rolled rather than pulling in `get_it` — it is a few lines
/// and keeps the dependency list empty. The API is close enough that switching
/// later is a mechanical change.
class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator instance = ServiceLocator._();

  final Map<Type, Object Function()> _factories = {};
  final Map<Type, Object> _singletons = {};

  /// Registers a dependency built once, on first use.
  void registerLazySingleton<T extends Object>(T Function() create) {
    _factories[T] = create;
  }

  /// Registers a dependency built fresh on every resolve — use for controllers
  /// and anything holding per-screen state.
  void registerFactory<T extends Object>(T Function() create) {
    _factories[T] = create;
    _singletons.remove(T);
    _transient.add(T);
  }

  final Set<Type> _transient = {};

  /// Lets call sites read as `sl<SelectRole>()`, matching the `get_it` idiom.
  T call<T extends Object>() => get<T>();

  T get<T extends Object>() {
    if (!_transient.contains(T) && _singletons.containsKey(T)) {
      return _singletons[T]! as T;
    }

    final create = _factories[T];
    if (create == null) {
      throw StateError(
        '$T is not registered. Add it in configureDependencies().',
      );
    }

    final instance = create() as T;
    if (!_transient.contains(T)) _singletons[T] = instance;
    return instance;
  }

  /// Whether anything is registered for [T].
  ///
  /// For the handful of callers that can work without a dependency rather than
  /// fail on it — a widget that reads the session to authenticate an image
  /// request, and renders initials when there is no session to read. [get]
  /// stays the strict form: a screen missing its controller is a bug, not a
  /// case to degrade around.
  bool isRegistered<T extends Object>() => _factories.containsKey(T);

  /// Clears every registration — used between tests.
  void reset() {
    _factories.clear();
    _singletons.clear();
    _transient.clear();
  }
}

/// Shorthand used at call sites: `sl<SelectRole>()`.
final ServiceLocator sl = ServiceLocator.instance;
