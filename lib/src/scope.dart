// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.src.scope;

import 'package:august/august.dart';

class Scopes {
  final Run _run;
  final List<ScopeEnterEvent> _activeScopes = [];

  Iterable<ScopeEnterEvent> get activeScopes =>
      new List.unmodifiable(_activeScopes);

  Scopes(this._run);

  Future<ScopeEnterEvent> enter(Scope scope) {
    var event = new ScopeEnterEvent._(scope);
    _activeScopes.add(event);
    return _run.emit(event);
  }

  Future<ScopeExitEvent> exit(Scope scope) {
    var scopeEnterEvent = _activeScopes.lastWhere((e) => e.scope == scope);
    if (scopeEnterEvent == null) {
      throw new ArgumentError("Cannot exit a scope ($scope) that has not been "
          "entered");
    }
    _activeScopes.remove(scopeEnterEvent);
    return _run.emit(new ScopeExitEvent._(scope));
  }

  Stream<ScopeEnterEvent> get entries =>
      _run.every((e) => e is ScopeEnterEvent);

  Stream<ScopeExitEvent> get exits => _run.every((e) => e is ScopeExitEvent);
}

abstract class Scope {}

class ScopeEnterEvent {
  final Scope scope;

  ScopeEnterEvent._(this.scope);
}

class ScopeExitEvent {
  final Scope scope;

  ScopeExitEvent._(this.scope);
}

class ScopeListener {
  final StreamController _ctrl = new StreamController();

  ScopeListener(ScopeTest test, Scopes scopes) {
    int _enteredCount = 0;

    var eventsScopeMatches = (e) => test(e.scope);
    var matchingScopeEvents = scopes.activeScopes.where(eventsScopeMatches);

    _enteredCount += matchingScopeEvents.length;

    if (_enteredCount > 0) {
      _ctrl.add(matchingScopeEvents.first);
    }

    scopes.entries.where(eventsScopeMatches).listen((e) {
      _enteredCount += 1;
      if (_enteredCount == 1) {
        _ctrl.add(e);
      }
    });

    scopes.exits.where(eventsScopeMatches).listen((e) {
      _enteredCount -= 1;
      if (_enteredCount == 0) {
        _ctrl.add(e);
      }
    });
  }

  Stream<ScopeEnterEvent> get onEnter =>
      _ctrl.stream.where((e) => e is ScopeEnterEvent);

  Stream<ScopeExitEvent> get onExit =>
      _ctrl.stream.where((e) => e is ScopeExitEvent);
}

typedef bool ScopeTest(Scope scope);
