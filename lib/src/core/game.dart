// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

class Game {
  /// Main broadcast stream controller which serves an [Event] sink as well as
  /// the [Stream] of [Event]s. Listening and broadcasting events is the
  /// central mechanic of communicating between actors and changing state.
  final StreamController<Event> _ctrl = new StreamController.broadcast(sync: true);

  /// Provides syntactic sugar for listening to events of a specific type.
  ///
  /// Example:
  ///
  /// ```
  /// game.on[DialogEvent].listen((e) => ...);
  /// ```
  Events _events;

  /// Before game is started, actors may not broadcast events.
  bool _hasBegun = false;

  /// Ordered log of all immutable [Event]s.
  final Journal journal;

  Events get on => _events;
  Stream<Event> get stream => _ctrl.stream;

  Game([Journal journal])
      : this.journal = (journal != null) ? journal : _newDefaultJournal()  {
    _events = new Events(stream);

    _registerHandlers();

    addActor(this.journal);
  }

  FutureGame addActor(Actor a) {
    return new FutureGame(this, new Future(() => _addEvent(new AddActor(a))));
  }

  FutureGame addActors(List<Actor> actors) {
    var addActors = actors
        .map((a) => new Future(() => _addEvent(new AddActor(a))));

    return new FutureGame(this, Future.wait(addActors));
  }

  /// Schedule a new event to be broadcast to all registered listeners. The
  /// event will not be broadcast immediately, but some time after the current
  /// event loop cycle is done.
  ///
  /// It is an error to broadcast an [Event] before [begin] is called.
  ///
  /// Returns a [Future] that completes with the event when it is broadcast to
  /// all listeners.
  FutureGame broadcast(Event e) {
    _checkReadyToBroadcast(e);

    // Thanks, Günter! http://stackoverflow.com/a/29070144/2216134
    return new FutureGame(this, new Future(() => _addEvent(e)));
  }

  /// Schedule a new event to be broadcast to all registered listeners after
  /// the provided [Duration]. If it is 0 or less, it behaves as [broadcast].
  ///
  /// It is an error to broadcast an [Event] before [begin] is called.
  ///
  /// Returns a [Future] that completes with the event when it is broadcast to
  /// all listeners.
  FutureGame broadcastDelayed(Duration delay, Event e) {
    _checkReadyToBroadcast(e);

    return new FutureGame(this, new Future.delayed(delay, () => _addEvent(e)));
  }

  /// Allows [Event]s to be broadcast and [broadcast]s a [BeginEvent].
  void begin() {
    if (_hasBegun) {
      throw new StateError("Game has already begun!");
    }

    _hasBegun = true;

    _addEvent(new BeginEvent());
  }

  void _registerHandlers() {
    on[AddActor].listen((e) {
      e.actor.prepare(this);

      if (_hasBegun) {
        e.actor.action(this);
      } else {
        on[BeginEvent].listen((_) => e.actor.action(this));
      }
    });
  }

  _checkReadyToBroadcast(Event e) {
    if (!_hasBegun) {
      throw new StateError("Event broadcast before game started: $e");
    }
  }

  _addEvent(Event e) {
    e._timeStamp = new DateTime.now();
    _ctrl.add(e);
  }
}

class FutureGame {
  final Game _game;
  final Future _future;

  FutureGame(this._game, this._future);

  FutureGame thenAddActor(Actor a) {
    return new FutureGame(_game,
        _future.then((_) => _game.addActor(a)));
  }

  FutureGame thenAddActors(List<Actor> actors) {
    return new FutureGame(_game,
        _future.then((_) => _game.addActors(actors)));
  }

  FutureGame thenBroadcast(Event e) {
    return new FutureGame(_game,
        _future.then((_) => _game.broadcast(e)));
  }

  FutureGame thenBroadcastDelayed(Duration delay, Event e) {
    return new FutureGame(_game,
        _future.then((_) => _game.broadcastDelayed(delay, e)));
  }

  Future then(dynamic computation(dynamic)) {
    return _future.then(computation);
  }

  _addEvent(Event e) {
    e._timeStamp = new DateTime.now();
    _game._ctrl.add(e);
  }
}

class Events {
  final Stream<Event> _events;

  Events(this._events);

  Stream<Event> operator [](Type eventType) =>
      _events.where((e) => e.runtimeType == eventType);
}

Journal _newDefaultJournal() {
  return new Journal(shouldLog: true);
}
