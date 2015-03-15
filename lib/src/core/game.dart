// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

class Game {
  /// Main broadcast stream controller which serves an [Event] sink as well as
  /// the [Stream] of [Event]s. Listening and broadcasting events is the
  /// central mechanic of communicating between actors and changing state.
  StreamController<Event> _ctrl;

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
  Stream<Event> get events => _ctrl.stream;

  Game([Journal journal])
      : this.journal = (journal != null) ? journal : _newDefaultJournal()  {
    _ctrl = new StreamController.broadcast();
    _events = new Events(events);

    _registerHandlers();

    addActor(this.journal);
  }

  void addActor(Actor a) {
    _ctrl.add(new AddActor(a));
  }

  void addActors(List<Actor> actors) {
    actors.forEach(addActor);
  }

  /// Broadcast an event to all registered listeners. It is an error to
  /// broadcast an [Event] before [begin] is called.
  void broadcast(Event e) {
    if (!_hasBegun) {
      throw new StateError("Event broadcast before game started: $e");
    }

    _ctrl.add(e);
  }

  /// Allows [Event]s to be broadcast and [broadcast]s a [BeginEvent].
  void begin() {
    _hasBegun = true;

    broadcast(new BeginEvent());
  }

  void _registerHandlers() {
    on[AddActor].listen((e) {
      e.actor.prepare(this);

      if (_hasBegun) {
        e.actor.action(this);
      } else {
        on[BeginEvent].listen((e) => e.actor.action(this));
      }
    });
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
