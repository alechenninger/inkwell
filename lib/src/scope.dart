// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

part of '../august.dart';

typedef GetScope = Scope Function();

Always getAlways() {
  return always;
}

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

  Scope<T> where(bool Function() isTrue) {
    return PredicatedScope(isTrue, this);
  }

  Scope and(Scope scope) {
    return merge(scope, latest((s1, s2) => s1 && s2));
  }

  Scope merge(Scope scope, bool Function(bool, bool) merger) {}

  Observed<bool> get asObserved => null;

  /// Shorthand to listening to [onEnter] and [onExit] streams of the scope
  /// with the given [onEnter] and [onExit] callbacks.
  ///
  /// Calls [onEnter] with `null` if the scope is already entered and
  /// [callIfAlreadyEntered] is `true`.
  void listen(
      {void Function(T) onEnter,
      void Function(T) onExit,
      callIfAlreadyEntered = true}) {
    this.onEnter.listen(onEnter);
    this.onExit.listen(onExit);
    if (isEntered && callIfAlreadyEntered) {
      onEnter(null);
    }
  }

// TODO: Maybe add a convenience API for listen to onEnter + check isEntered
//  void around({onEnter(Scope<T> scope), onExit(Scope<T> scope)}) {
//    if (isEntered) onEnter(this);
//    this.onEnter.listen((_) { onEnter(this); });
//    this.onExit.listen((_) { onExit(this); });
//  }
}

const always = Always();
const never = Never();

class Always extends Scope<void> {
  final isEntered = true;
  final isNotEntered = false;
  final onEnter = const Stream<Null>.empty();
  final onExit = const Stream<Null>.empty();

  const Always();

  Scope<void> where(bool Function() isTrue) => isTrue() ? this : const Never();
}

class Never extends Scope<void> {
  final isEntered = false;
  final isNotEntered = true;
  final onEnter = const Stream<Null>.empty();
  final onExit = const Stream<Null>.empty();

  const Never();

  Scope<void> where(bool Function() isTrue) => this;
}

class AndScope extends Scope<dynamic> {
  final Scope _first;
  final Scope _second;
  // Use synchronous broadcast streams because we are already listening on the
  // back of an async context; the microtask listener of the scope events.
  // Listening to an AndScope should be transparent and not add another layer of
  // microtasks.
  /*
  TODO: the behavior of this is a bit odd. Because these are separate streams
    and the backing scopes listeners are fired in separate microtasks,
    listeners can subscribe to an AndScope and inadvertently get events
    they wouldn't otherwise, because of the microtask delay of events.

  For example:

  1. loop 1: s1 already entered.
  2. loop 1: s2 not entered.
  3. loop 1: andscope subscribes to s2.
  4. loop 1: s2 enters. andscope listener, so queued in mt.
  5. loop 1: l1 subscribes to andscope.
  5. loop 2 (mt): andscope listener called. in scope. notifies l1.
  6. loop 3 (mt): l1 notified.

  in this example, l1 is notified of a change that happened before it
  subscribed.

  */
  final _enters = StreamController.broadcast(sync: true);
  final _exits = StreamController.broadcast(sync: true);
  bool _currentlyEntered;

  AndScope(this._first, this._second) {
    // TODO: Properly clean up once _enters and _exits have no listeners

    _currentlyEntered = _first.isEntered && _second.isEntered;

    var enterDoneCount = 0;
    var exitDoneCount = 0;

    void enterDone() {
      if (++enterDoneCount == 2) {
        _enters.close();
      }
    }

    void exitDone() {
      if (++exitDoneCount == 2) {
        _exits.close();
      }
    }

    _first.onEnter.where((e) => _second.isEntered && !_currentlyEntered).listen(
        (e) {
          _currentlyEntered = true;
          _enters.add(null);
        }, onDone: enterDone);

    _second.onEnter.where((e) => _first.isEntered && !_currentlyEntered).listen(
        (e) {
          _currentlyEntered = true;
          _enters.add(null);
        }, onDone: enterDone);

    _first.onExit.where((_) => _currentlyEntered).listen((e) {
      _currentlyEntered = false;
      _exits.add(null);
    }, onDone: exitDone);
    _second.onExit.where((_) => _currentlyEntered).listen((e) {
      _currentlyEntered = false;
      _exits.add(null);
    }, onDone: exitDone);
  }

  bool get isEntered => _first.isEntered && _second.isEntered;

  Stream get onEnter => _enters.stream;

  Stream get onExit => _exits.stream;
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

class ScopeOfObserved extends Scope<Change<bool>> {
  final Observed<bool> _observed;
  Observed<bool> get asObserved => _observed;

  ScopeOfObserved(this._observed);

  bool get isEntered => _observed.value;

  Stream<Change<bool>> get onEnter =>
      _observed.onChange.where((e) => e.newValue);

  Stream<Change<bool>> get onExit =>
      _observed.onChange.where((e) => !e.newValue);
}

class SettableScope2 extends Scope<Change<bool>> {
  final Observable<bool> _scope;
  Observed<bool> get asObserved => _scope;

  SettableScope2._(bool isEntered) : _scope = Observable.ofImmutable(isEntered);

  SettableScope2.entered() : this._(true);

  SettableScope2.notEntered() : this._(false);

  void enter() {
    _scope.value = true;
  }

  void exit() {
    _scope.value = false;
  }

  void close() {
    _scope.close();
  }

  Scope merge(Scope scope, bool Function(bool, bool) merger) {
   return ScopeOfObserved(_scope.merge(scope.asObserved, merger));
  }

  Scope map(bool Function(bool) mapper) {
    return ScopeOfObserved(_scope.map(mapper));
  }

  bool get isClosed => _scope.isClosed;

  bool get isNotClosed => !isClosed;

  bool get isEntered => _scope.value;

  Stream<Change<bool>> get onEnter =>
      _scope.onChange.where((e) => e.newValue);

  Stream<Change<bool>> get onExit =>
      _scope.onChange.where((e) => !e.newValue);
}

class SettableScope<T> extends Scope<T> {
  final _enters = StreamController<T>.broadcast(sync: true);
  final _exits = StreamController<T>.broadcast(sync: true);

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
      throw StateError('Cannot enter a scope which has been closed.');
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
      throw StateError('Cannot exit a scope which has been closed.');
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
  final StreamController _enters = StreamController.broadcast(sync: true);
  final StreamController _exits = StreamController.broadcast(sync: true);

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
      : _settable = SettableScope.entered() {
    _init(eventStream, enterWhen, exitWhen, closeWhen);
  }

  ListeningScope.notEntered(Stream<T> eventStream,
      {bool enterWhen(T event) = _never,
      bool exitWhen(T event) = _never,
      bool closeWhen(T event) = _never})
      : _settable = SettableScope.notEntered() {
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

// A simple scope that is entered until incremented a maximum number of times.
// TODO: consider generalizing this a bit to be able to produce scopes off of
// various counts which all share the same counter
class CountScope extends Scope<int> {
  final int max;

  var _current = 0;

  int get current => _current;

  final SettableScope<int> _scope;

  bool get isEntered => _scope.isEntered;

  Stream<int> get onEnter => _scope.onEnter;

  Stream<int> get onExit => _scope.onExit;

  CountScope(int max)
      : max = max,
        _scope = max > 0
            ? SettableScope<int>.entered()
            : SettableScope<int>.notEntered();

  void increment() {
    if (_current == max) {
      throw StateError('Max of $max already met, cannot increment.');
    }

    _current++;

    if (_current == max) {
      _scope.exit(_current);
      _scope.close();
    }
  }
}

typedef GetNewValue<T> = T Function(T currentValue);
typedef Predicate = bool Function();

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
  final ForwardingScope _mirrorScope = ForwardingScope();

  Scope get scope => _mirrorScope;

  Scoped.ofImmutable(T initialValue,
      {T Function(T) enterValue, T Function(T) exitValue})
      : _observable = Observable<T>.ofImmutable(initialValue),
        _enterValue = enterValue ?? _identity,
        _exitValue = exitValue ?? _identity;

  void within(Scope scope,
      {T Function(T) enterValue, T Function(T) exitValue}) {
    _enterSubscription?.cancel();
    _exitSubscription?.cancel();

    _backingScope = scope;
    _mirrorScope.delegate = scope;

    if (enterValue != null) _enterValue = enterValue;
    if (exitValue != null) _exitValue = exitValue;

    if (_backingScope.isEntered) {
      _observable.value = _enterValue(_observable.value);
    } else {
      _observable.value = _exitValue(_observable.value);
    }

    _enterSubscription = _backingScope.onEnter.listen((e) {
      _observable.value = _enterValue(_observable.value);
    });

    _exitSubscription = _backingScope.onExit.listen((e) {
      _observable.value = _exitValue(_observable.value);
    });
  }
}

/// Scopes encode a simple boolean state: entered or not entered. Sometimes it
/// is useful to use that flag as an [Observable] value.
class ScopeAsValue {
  Scoped<bool> _scoped;

  Observed<bool> get observed => _scoped.observed;

  ListeningScope<Change<bool>> _valueScope;

  /// Treats the observed scope change itself as a scope. This is not to be
  /// confused with the scope that determines the observed value.
  Scope<Change<bool>> get asScope => _valueScope;

  Scope get scope => _scoped.scope;

  /// Starts as not entered until a scope is set. Set a scope with [within].
  ScopeAsValue() {
    _scoped = Scoped.ofImmutable(false,
        enterValue: (_) => true, exitValue: (_) => false);

    _valueScope = ListeningScope.notEntered(_scoped.observed.onChange,
        enterWhen: (e) => e.newValue == true,
        exitWhen: (e) => e.newValue == false);
  }

  void within(Scope scope) {
    _scoped.within(scope);
  }
}

T _identity<T>(T value) => value;

bool _never(e) => false;
