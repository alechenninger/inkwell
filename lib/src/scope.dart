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
  /// Immediately available. That is, visible just prior to onEnter or onExit
  /// events being emitted.
  bool get isEntered;

  /// Streams are broadcast streams, which means if the scope is entered before
  /// entries are listened to, the listener will _not_ get an entry event,
  /// because it already happened. You can check if a scope is currently entered
  /// using [isEntered].
  ///
  /// Some scopes may enter and exit multiple times.
  ///
  /// Streams should emit a done event when a scope is no longer able to be
  /// entered.
  Stream<T> get onEnter;

  /// Streams are broadcast streams, which means if the scope is exited before
  /// exits are listened to, the listener will _not_ get an exit event, because
  /// it already happened. You can check if a scope is currently entered using
  /// [isEntered].
  ///
  /// Some scopes may enter and exit multiple times.
  ///
  /// Streams should emit a done event when a scope is no longer able to be
  /// exited.
  Stream<T> get onExit;
}

typedef ScopeListener(event);

// TODO: Could add value computations for value when in scope and value when
// not in scope
class Scoped {
  final SettableScope _scope = new SettableScope.notEntered();
  Scope get scope => _scope;

  ScopeListener _onEnter;
  ScopeListener _onExit;

  Scope _currentScope = const Never();

  StreamSubscription _enterSubscription;
  StreamSubscription _exitSubscription;

  Scoped({ScopeListener onEnter: _noop, ScopeListener onExit: _noop})
      : _onEnter = onEnter,
        _onExit = onExit;

  bool get isInScope => _currentScope.isEntered;

  void within(Scope scope,
      {ScopeListener onEnter: null, ScopeListener onExit: null}) {
    _enterSubscription?.cancel();
    _exitSubscription?.cancel();

    _currentScope = scope;

    if (onEnter != null) _onEnter = onEnter;
    if (onExit != null) _onExit = onExit;

    if (scope.isEntered) {
      _onEnter(null);
      _scope.enter(null);
    }

    _enterSubscription = _currentScope.onEnter.listen((e) {
      _onEnter(e);
      _scope.enter(e);
    });

    _exitSubscription = _currentScope.onExit.listen((e) {
      _onExit(e);
      _scope.exit(e);
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
  bool _previouslyEntered;

  AndScope(this._first, this._second) {
    // TODO: Properly clean up once _enters and _exits have no listeners
    _previouslyEntered = isEntered;

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

    _first.onEnter
        .where((e) => _second.isEntered && !_previouslyEntered)
        .listen((e) {
      _enters.add(e);
    }, onDone: enterDone);

    _second.onEnter
        .where((e) => _first.isEntered && !_previouslyEntered)
        .listen((e) {
      _enters.add(e);
    }, onDone: enterDone);

    _first.onExit
        .where((e) => !_second.isEntered && _previouslyEntered)
        .listen((e) {
      _exits.add(e);
    }, onDone: exitDone);

    _second.onExit
        .where((e) => !_first.isEntered && _previouslyEntered)
        .listen((e) {
      _exits.add(e);
    }, onDone: exitDone);

    _onEnter = _enters.stream;
    _onExit = _exits.stream;

    _onEnter.listen((_) => _previouslyEntered = true);
    _onExit.listen((_) => _previouslyEntered = false);
  }

  bool get isEntered => _first.isEntered && _second.isEntered;

  Stream _onEnter;
  Stream get onEnter => _onEnter;

  Stream _onExit;
  Stream get onExit => _onExit;
}

class SettableScope implements Scope {
  final StreamController _enters = new StreamController.broadcast(sync: true);
  final StreamController _exits = new StreamController.broadcast(sync: true);

  SettableScope.entered() {
    _isEntered = true;
  }

  SettableScope.notEntered() {
    _isEntered = false;
  }

  void enter(event) {
    _isEntered = true;
    _enters.add(event);
  }

  void exit(event) {
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

typedef Scope GetScope();

void _noop(event) {}
