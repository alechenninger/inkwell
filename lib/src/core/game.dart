// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

abstract class Game {
  /// Ordered log of all immutable [Event]s.
  Journal get journal;

  /// Provides syntactic sugar for listening to events of a specific type.
  ///
  /// Example:
  ///
  /// ```
  /// game.on[DialogEvent].listen((e) => ...);
  /// ```
  Events get on;

  Stream<Event> get stream;

  /// Adds [actors] to the game, calling their [Actor.beforeBegin] callbacks
  /// before firing off a [BeginEvent]. Actors should use `beforeBegin` to
  /// register event handlers, and `onBegin` to fire events if necessary.
  static Game begin(List<Actor> actors, [Journal getJournal(Game)]) {
    getJournal = (getJournal != null) ? getJournal : _newDefaultJournal;
    return new _Game(actors, getJournal);
  }

  Future addActor(Actor a) {
    return broadcast(new AddActor(a));
  }

  Future addActors(List<Actor> actors) {
    var broadcastActors = actors
        .map((a) => broadcast(new AddActor(a)));

    return Future.wait(broadcastActors);
  }

  Future addOption(Option option) {
    return broadcast(new AddOption(option));
  }

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
}

class _Game extends Game {
  /// Main broadcast stream controller which serves an [Event] sink as well as
  /// the [Stream] of [Event]s. Listening and broadcasting events is the
  /// central mechanic of communicating between actors and changing state.
  final StreamController<Event> _ctrl = new StreamController.broadcast(sync: true);

  Events _events;

  Journal _journal;

  bool _hasBegun = false;

  Journal get journal => _journal;

  Events get on => _events;

  Stream<Event> get stream => _ctrl.stream;

  _Game(List<Actor> actors, Journal getJournal(Game)) {
    _journal = getJournal(this);
    _events = new Events(stream);

    _registerHandlers();

    actors.forEach((a) => _addEvent(new AddActor(a)));

    _hasBegun = true;

    broadcast(new BeginEvent());
  }

  Future broadcast(Event e) {
    // Thanks, Günter! http://stackoverflow.com/a/29070144/2216134
    return new Future(() => _addEvent(e));
  }

  Future broadcastDelayed(Duration delay, Event e) {
    return new Future.delayed(delay, () => _addEvent(e));
  }

  _registerHandlers() {
    on[AddActor].listen((e) {
      e.actor.beforeBegin(this);

      if (_hasBegun) {
        e.actor.onBegin(this);
      } else {
        on[BeginEvent].listen((_) => e.actor.onBegin(this));
      }
    });
  }

  /// Synchronously add an event to the broadcast stream
  Event _addEvent(Event e) {
    e._timeStamp = new DateTime.now();
    _ctrl.add(e);
    return e;
  }
}

class Events {
  final Stream<Event> _events;

  Events(this._events);

  /// [eventType] may be a [Type] or an instance of a specific event.
  Stream<Event> operator [](dynamic eventOrType) {
      if (eventOrType is Type) {
        return _events.where((e) => e.runtimeType == eventOrType);
      }

      return _events.where((e) => e == eventOrType);
  }
}

Journal _newDefaultJournal(game) {
  return new Journal(game, shouldLog: true);
}
