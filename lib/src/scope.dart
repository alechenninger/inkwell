// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august;

/// Cached knowledge of a particular story state.
///
/// Any boundaries of particular events may be defined as a "scope." It can be
/// defined by boundaries such as a period of time, while in a specific location
/// or locations, while in a scene, or any combination of the above.
///
/// Scopes are used to control availability or state of other story objects like
/// options or dialog.
abstract class Scope<T> {
  /// Immediately available in the current event loop, just before onEnter and
  /// onExit events are fired.
  bool get isEntered;

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
}

typedef dynamic GetNewValue(currentValue);

class Scoped<T> {
  Scope _backingScope = const Never();

  final Observable<T> _observable;
  T get value => _observable.value;

  Stream<StateChangeEvent<T>> get onChange => _observable.onChange;

  GetNewValue _enterValue;
  GetNewValue _exitValue;

  StreamSubscription _enterSubscription;
  StreamSubscription _exitSubscription;

  final ForwardingScope _mirrorScope = new ForwardingScope();
  Scope get scope => _mirrorScope;

  Scoped.ofImmutable(T initialValue,
      {T enterValue(T value): _identity, T exitValue(T value): _identity})
      : _observable = new Observable<T>.ofImmutable(initialValue),
        _enterValue = enterValue,
        _exitValue = exitValue;

  void within(Scope scope,
      {T enterValue(T value): null, T exitValue(T value): null}) {
    _enterSubscription?.cancel();
    _exitSubscription?.cancel();

    _backingScope = scope;
    _mirrorScope.delegate = scope;

    if (enterValue != null) _enterValue = enterValue;
    if (exitValue != null) _exitValue = exitValue;

    if (_backingScope.isEntered) {
      _observable.set(_enterValue);
    }

    _enterSubscription = _backingScope.onEnter.listen((e) {
      _observable.set(_enterValue);
    });

    _exitSubscription = _backingScope.onExit.listen((e) {
      _observable.set(_exitValue);
    });
  }
}

class Always implements Scope<Null> {
  final bool isEntered = true;
  final onEnter = const Stream.empty();
  final onExit = const Stream.empty();

  const Always();
}

class Never implements Scope<Null> {
  final bool isEntered = false;
  final onEnter = const Stream.empty();
  final onExit = const Stream.empty();

  const Never();
}

class AndScope implements Scope<dynamic> {
  final Scope _first;
  final Scope _second;
  final StreamController _enters = new StreamController.broadcast(sync: true);
  final StreamController _exits = new StreamController.broadcast(sync: true);
  bool _currentlyEntered;

  AndScope(this._first, this._second) {
    // TODO: Properly clean up once _enters and _exits have no listeners
    _currentlyEntered = isEntered;

    int enterDoneCount = 0;
    int exitDoneCount = 0;

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

    _first.onExit.where((e) => !_second.isEntered && _currentlyEntered).listen(
        (e) {
      _exits.add(e);
    }, onDone: exitDone);

    _second.onExit.where((e) => !_first.isEntered && _currentlyEntered).listen(
        (e) {
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

class SettableScope implements Scope {
  // TODO: API for closing scope
  final StreamController _enters = new StreamController.broadcast(sync: true);
  final StreamController _exits = new StreamController.broadcast(sync: true);

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
  void enter(event) {
    if (_isEntered) return;

    _isEntered = true;
    _enters.add(event);
  }

  /// Immediately changes scope state and calls onExit listeners.
  ///
  /// If called multiple times before an [enter], listeners are only fired for
  /// the first call.
  void exit(event) {
    if (!_isEntered) return;

    _isEntered = false;
    _exits.add(event);
  }

  bool _isEntered;
  bool get isEntered => _isEntered;

  Stream _onEnter;
  Stream get onEnter => _onEnter;

  Stream _onExit;
  Stream get onExit => _onExit;
}

class ForwardingScope implements Scope {
  // TODO: API for closing scope
  final StreamController _enters = new StreamController.broadcast(sync: true);
  final StreamController _exits = new StreamController.broadcast(sync: true);

  Scope _delegate;
  StreamSubscription _delegateEnterSubscription;
  StreamSubscription _delegateExitSubscription;

  void set delegate(Scope delegate) {
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

  ForwardingScope([delegate = const Never()]) {
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

class ListeningScope implements Scope {
  final SettableScope _settable;

  ListeningScope.entered(Stream eventStream,
      {EventTest isEnterEvent: _noEvents, EventTest isExitEvent: _noEvents})
      : _settable = new SettableScope.entered() {
    eventStream.where(isEnterEvent).listen(_settable.enter);
    eventStream.where(isExitEvent).listen(_settable.exit);
  }

  ListeningScope.notEntered(Stream eventStream,
      {EventTest enterWhen: _noEvents, EventTest exitWhen: _noEvents})
      : _settable = new SettableScope.notEntered() {
    eventStream.where(enterWhen).listen(_settable.enter);
    eventStream.where(exitWhen).listen(_settable.exit);
  }

  bool get isEntered => _settable.isEntered;

  Stream get onEnter => _settable.onEnter;

  Stream get onExit => _settable.onExit;
}

typedef Scope GetScope();

dynamic _identity(value) => value;

bool _noEvents(e) {
  return false;
}
