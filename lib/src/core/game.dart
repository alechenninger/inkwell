// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

abstract class Game {
  /// Ordered log of all immutable [Event]s.
  Journal get journal;

  Events get on;

  Stream<Event> get stream;

  factory Game([Journal journal]) {
    return new _Game((journal != null) ? journal : _newDefaultJournal());
  }

  Future<Event> addActor(Actor actor);

  Future<List<Event>> addActors(List<Actor> actors);

  /// Schedule a new event to be broadcast to all registered listeners. The
  /// event will not be broadcast immediately, but some time after the current
  /// event loop cycle is done.
  ///
  /// It is an error to broadcast an [Event] before [begin] is called.
  ///
  /// Returns a [Future] that completes with the event when it is broadcast to
  /// all listeners.
  Future<Event> broadcast(Event event);

  /// Schedule a new event to be broadcast to all registered listeners after
  /// the provided [Duration]. If it is 0 or less, it behaves as [broadcast].
  ///
  /// It is an error to broadcast an [Event] before [begin] is called.
  ///
  /// Returns a [Future] that completes with the event when it is broadcast to
  /// all listeners.
  Future<Event> broadcastDelayed(Duration delay, Event event);

  void begin();
}

class _Game implements Game {
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

  final Journal journal;

  Events get on => _events;

  Stream<Event> get stream => _ctrl.stream;

  _Game(this.journal) {
    _events = new Events(stream);
    _registerHandlers();
    addActor(this.journal);
  }

  Future addActor(Actor a) {
    return new Future(() => _addEvent(new AddActor(a)));
  }

  Future addActors(List<Actor> actors) {
    var addActors = actors
        .map((a) => new Future(() => _addEvent(new AddActor(a))));

    return Future.wait(addActors);
  }

  Future broadcast(Event e) {
    _checkReadyToBroadcast(e);

    // Thanks, Günter! http://stackoverflow.com/a/29070144/2216134
    return new Future(() => _addEvent(e));
  }

  Future broadcastDelayed(Duration delay, Event e) {
    _checkReadyToBroadcast(e);

    return new Future.delayed(delay, () => _addEvent(e));
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
      e.actor.beforeBegin(this);

      if (_hasBegun) {
        e.actor.onBegin(this);
      } else {
        on[BeginEvent].listen((_) => e.actor.onBegin(this));
      }
    });
  }

  _checkReadyToBroadcast(Event e) {
    if (!_hasBegun) {
      throw new StateError("Event broadcast before game started: $e");
    }
  }

  Event _addEvent(Event e) {
    e._timeStamp = new DateTime.now();
    _ctrl.add(e);
    return e;
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
