// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august;

/// Defines a period of time by enter and exit event streams.
///
/// `Scope`s are used to control availability or state of other story objects
/// like options or dialog.
///
/// Any boundaries of particular events may be defined as a `Scope`. For
/// example, boundaries can be defined by specific date times or any predicate
/// on story state like location or inventory. `Scope`s are very flexible and
/// intended as a core building block for arbitrarily complicated state rules.
// TODO: Rethink parameterized type usage here
abstract class Scope<T> {
  const Scope();

  /// Immediately available in the current event loop, just before onEnter and
  /// onExit events are fired.
  bool get isEntered;

  /// See [isEntered]
  bool get isNotEntered => !isEntered;

  /// Streams are synchronous broadcast streams, which means if the scope is
  /// entered before entries are listened to, the listener will _not_ get an
  /// entry event, because it already happened. You can check if a scope is
  /// currently entered using [isEntered].
  ///
  /// Listeners will be fired immediately in the same event loop.
  ///
  /// Some scopes may enter and exit multiple times.
  ///
  /// Streams should emit a done event when a scope is no longer able to be
  /// entered.
  Stream<T> get onEnter;

  /// Streams are synchronous broadcast streams, which means if the scope is
  /// exited before exits are listened to, the listener will _not_ get an exit
  /// event, because it already happened. You can check if a scope is currently
  /// entered using [isEntered].
  ///
  /// Listeners will be fired immediately in the same event loop.
  ///
  /// Some scopes may enter and exit multiple times.
  ///
  /// Streams should emit a done event when a scope is no longer able to be
  /// exited.
  Stream<T> get onExit;

  Scope<T> where(bool isTrue()) {
    return new PredicatedScope(isTrue, this);
  }

// TODO: Maybe add a convenience API for listen to onEnter + check isEntered
//  void around({onEnter(Scope<T> scope), onExit(Scope<T> scope)}) {
//    if (isEntered) onEnter(this);
//    this.onEnter.listen((_) { onEnter(this); });
//    this.onExit.listen((_) { onExit(this); });
//  }
}

const Scope always = const Always();
const Scope never = const Never();

class Always extends Scope<Null> {
  final isEntered = true;
  final isNotEntered = false;
  final onEnter = const Stream<Null>.empty();
  final onExit = const Stream<Null>.empty();

  const Always();

  Scope<Null> where(bool isTrue()) => isTrue() ? this : const Never();
}

class Never extends Scope<Null> {
  final isEntered = false;
  final isNotEntered = true;
  final onEnter = const Stream<Null>.empty();
  final onExit = const Stream<Null>.empty();

  const Never();

  Scope<Null> where(bool isTrue()) => this;
}

class AndScope extends Scope<dynamic> {
  final Scope _first;
  final Scope _second;
  final StreamController _enters = new StreamController.broadcast(sync: true);
  final StreamController _exits = new StreamController.broadcast(sync: true);
  bool _currentlyEntered;

  AndScope(this._first, this._second) {
    // TODO: Properly clean up once _enters and _exits have no listeners
    _currentlyEntered = isEntered;

    var enterDoneCount = 0;
    var exitDoneCount = 0;

    enterDone() {
      if (++enterDoneCount == 2) {
        _enters.close();
      }
    }

    exitDone() {
      if (++exitDoneCount == 2) {
        _exits.close();
      }
    }

    _first.onEnter.where((e) => _second.isEntered && !_currentlyEntered).listen(
        (e) {
      _enters.add(e);
    }, onDone: enterDone);

    _second.onEnter.where((e) => _first.isEntered && !_currentlyEntered).listen(
        (e) {
      _enters.add(e);
    }, onDone: enterDone);

    _first.onExit.where((e) => _currentlyEntered).listen((e) {
      _exits.add(e);
    }, onDone: exitDone);

    _second.onExit.where((e) => _currentlyEntered).listen((e) {
      _exits.add(e);
    }, onDone: exitDone);

    _onEnter = _enters.stream;
    _onExit = _exits.stream;

    _onEnter.listen((_) => _currentlyEntered = true);
    _onExit.listen((_) => _currentlyEntered = false);
  }

  bool get isEntered => _first.isEntered && _second.isEntered;

  Stream _onEnter;

  Stream get onEnter => _onEnter;

  Stream _onExit;

  Stream get onExit => _onExit;
}

class PredicatedScope<T> extends Scope<T> {
  final Predicate _predicate;
  final Scope<T> _delegate;
  bool _satisfiedPredicate;

  PredicatedScope(this._predicate, this._delegate) {
    _satisfiedPredicate = _predicate();
  }

  bool get isEntered => _satisfiedPredicate && _delegate.isEntered;

  Stream<T> get onEnter => _delegate.onEnter.where((e) {
        return _satisfiedPredicate = _predicate();
      });

  Stream<T> get onExit => _delegate.onExit;
}

class SettableScope<T> extends Scope<T> {
  final _enters = new StreamController<T>.broadcast(sync: true);
  final _exits = new StreamController<T>.broadcast(sync: true);

  SettableScope._(this._isEntered) {
    _onEnter = _enters.stream;
    _onExit = _exits.stream;
  }

  SettableScope.entered() : this._(true);

  SettableScope.notEntered() : this._(false);

  /// Immediately changes scope state and calls onEnter listeners.
  ///
  /// If called multiple times before an [exit], listeners are only fired for
  /// the first call.
  void enter(T event) {
    if (_isEntered) return;
    if (_enters.isClosed) {
      throw new StateError("Cannot enter a scope which has been closed.");
    }

    _isEntered = true;
    _enters.add(event);
  }

  /// Immediately changes scope state and calls onExit listeners.
  ///
  /// If called multiple times before an [enter], listeners are only fired for
  /// the first call.
  void exit(T event) {
    if (!_isEntered) return;
    if (_exits.isClosed) {
      throw new StateError("Cannot enter a scope which has been closed.");
    }

    _isEntered = false;
    _exits.add(event);
  }

  void close() {
    _enters.close();
    _exits.close();
  }

  bool _isEntered;

  bool get isEntered => _isEntered;

  bool get isClosed => _enters.isClosed;

  bool get isNotClosed => !isClosed;

  Stream<T> _onEnter;

  Stream<T> get onEnter => _onEnter;

  Stream<T> _onExit;

  Stream<T> get onExit => _onExit;

  // TODO onClose ?

  Scope<T> transform(
      {void onEnter(T value, SettableScope<T> scope),
      void onExit(T value, SettableScope<T> scope)}) {
    return isEntered
        ? new TransformScope.entered(this, onEnter: onEnter, onExit: onExit)
        : new TransformScope.notEntered(this, onEnter: onEnter, onExit: onExit);
  }
}

// TODO type parameters
class ForwardingScope extends Scope {
  // TODO: API for closing scope
  // Closing scope cant come from delegate because we can change the delegate
  // Would have to be API on forwarding scope itself to close this scope
  // "I'm done and won't delegate anything else with this scope"
  // Alternatively we could flag delegate with whether to use the delegate's
  // close or not... in either case delegating again after close must be an
  // error.
  final StreamController _enters = new StreamController.broadcast(sync: true);
  final StreamController _exits = new StreamController.broadcast(sync: true);

  Scope _delegate;
  StreamSubscription _delegateEnterSubscription;
  StreamSubscription _delegateExitSubscription;

  set delegate(Scope delegate) {
    if (_delegate != null) {
      _delegateEnterSubscription.cancel();
      _delegateExitSubscription.cancel();
    }

    _delegate = delegate;
    if (_delegate.isEntered) {
      _enters.add(null);
    }
    _delegateEnterSubscription = _delegate.onEnter.listen(_enters.add);
    _delegateExitSubscription = _delegate.onExit.listen(_exits.add);
  }

  ForwardingScope([Scope delegate = const Never()]) {
    this.delegate = delegate;
    _onEnter = _enters.stream;
    _onExit = _exits.stream;
  }

  bool get isEntered => _delegate.isEntered;

  Stream _onEnter;

  Stream get onEnter => _onEnter;

  Stream _onExit;

  Stream get onExit => _onExit;
}

/// A scope which is entered, exited, and closed when events in a given stream
/// match provided predicates.
class ListeningScope<T> extends Scope<T> {
  final SettableScope<T> _settable;

  ListeningScope.entered(Stream<T> eventStream,
      {bool enterWhen(T event) = _never,
      bool exitWhen(T event) = _never,
      bool closeWhen(T event) = _never})
      : _settable = new SettableScope.entered() {
    _init(eventStream, enterWhen, exitWhen, closeWhen);
  }

  ListeningScope.notEntered(Stream<T> eventStream,
      {bool enterWhen(T event) = _never,
      bool exitWhen(T event) = _never,
      bool closeWhen(T event) = _never})
      : _settable = new SettableScope.notEntered() {
    _init(eventStream, enterWhen, exitWhen, closeWhen);
  }

  _init(Stream<T> eventStream, bool enterWhen(T event), bool exitWhen(T event),
      bool closeWhen(T event)) {
    eventStream.listen((e) {
      bool shouldEnter = enterWhen(e);
      bool shouldExit = exitWhen(e);
      bool shouldClose = closeWhen(e);

      if (shouldEnter && !shouldExit) {
        _settable.enter(e);
      }

      if (shouldExit) {
        _settable.exit(e);
      }

      if (shouldClose) {
        _settable.close();
      }
    });
  }

  bool get isEntered => _settable.isEntered;

  Stream<T> get onEnter => _settable.onEnter;

  Stream<T> get onExit => _settable.onExit;
}

/// A scope that is a function of another scope.
class TransformScope<T> extends Scope<T> {
  final SettableScope<T> _backing;

  TransformScope._(
      this._backing,
      Scope<T> original,
      void onEnter(T value, SettableScope<T> scope),
      void onExit(T value, SettableScope<T> scope)) {
    if (onEnter != null) original.onEnter.listen((t) => onEnter(t, _backing));
    if (onExit != null) original.onExit.listen((t) => onExit(t, _backing));
  }

  TransformScope.entered(Scope<T> original,
      {void onEnter(T value, SettableScope<T> scope),
      void onExit(T value, SettableScope<T> scope)})
      : this._(new SettableScope.entered(), original, onEnter, onExit);

  TransformScope.notEntered(Scope<T> original,
      {void onEnter(T value, SettableScope<T> scope),
      void onExit(T value, SettableScope<T> scope)})
      : this._(new SettableScope.notEntered(), original, onEnter, onExit);

  bool get isEntered => _backing.isEntered;

  Stream<T> get onEnter => _backing.onEnter;

  Stream<T> get onExit => _backing.onExit;
}

typedef T GetNewValue<T>(T currentValue);
typedef bool Predicate();

/// Encapsulates a value which changes based on a scope.
class Scoped<T> {
  /// The mutable scope used to determine the [observed] value.
  Scope _backingScope = const Never();

  final Observable<T> _observable;

  Observed<T> get observed => _observable;

  GetNewValue<T> _enterValue;
  GetNewValue<T> _exitValue;

  StreamSubscription _enterSubscription;
  StreamSubscription _exitSubscription;

  /// An immutable scope instance which always matches the current
  /// [_backingScope] exactly, even if it is reassigned.
  final ForwardingScope _mirrorScope = new ForwardingScope();

  Scope get scope => _mirrorScope;

  Scoped.ofImmutable(T initialValue,
      {T enterValue(T value) = _identity,
      T exitValue(T value) = _identity,
      dynamic owner})
      : _observable = new Observable<T>.ofImmutable(initialValue, owner: owner),
        _enterValue = enterValue,
        _exitValue = exitValue;

  void within(Scope scope,
      {T enterValue(T value), T exitValue(T value)}) {
    _enterSubscription?.cancel();
    _exitSubscription?.cancel();

    _backingScope = scope;
    _mirrorScope.delegate = scope;

    if (enterValue != null) _enterValue = enterValue;
    if (exitValue != null) _exitValue = exitValue;

    if (_backingScope.isEntered) {
      _observable.set(_enterValue);
    } else {
      _observable.set(_exitValue);
    }

    _enterSubscription = _backingScope.onEnter.listen((e) {
      _observable.set(_enterValue);
    });

    _exitSubscription = _backingScope.onExit.listen((e) {
      _observable.set(_exitValue);
    });
  }
}

/// Scopes encode a simple boolean state: entered or not entered. Sometimes it
/// is useful to use that flag as an [Observable] value.
class ScopeAsValue {
  Scoped<bool> _scoped;

  Observed<bool> get observed => _scoped.observed;

  ListeningScope<StateChangeEvent<bool>> _valueScope;

  /// Treats the observed scope change itself as a scope. This is not to be
  /// confused with the scope that determines the observed value.
  Scope<StateChangeEvent<bool>> get asScope => _valueScope;

  Scope get scope => _scoped.scope;

  /// Starts as not entered until a scope is set. Set a scope with [within].
  ScopeAsValue({dynamic owner}) {
    _scoped = new Scoped.ofImmutable(false,
        owner: owner, enterValue: (_) => true, exitValue: (_) => false);

    _valueScope = new ListeningScope.notEntered(_scoped.observed.onChange,
        enterWhen: (e) => e.newValue == true,
        exitWhen: (e) => e.newValue == false);
  }

  void within(Scope scope) {
    _scoped.within(scope);
  }
}

T _identity<T>(T value) => value;

bool _never(e) => false;
