// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

class Game {
  StreamController<Event> _ctrl;
  Events _events;
  bool _started = false;

  Events get on => _events;
  Stream<Event> get events => _ctrl.stream;

  Game() {
    _ctrl = new StreamController.broadcast();
    _events = new Events(events);
  }

  /// Broadcast an event to all registered listeners. It is an error to broad
  /// cast an [Event] before [begin] is called.
  void broadcast(Event e) {
    if (!_started) {
      throw new StateError("Event emitted before director started: $e");
    }

    _ctrl.add(e);
  }

  /// Allows [Event]s to be broadcast and [broadcast]s a [BeginEvent].
  void begin() {
    _started = true;

    broadcast(new BeginEvent());
  }
}

class Events {
  final Stream<Event> _events;

  Events(this._events);

  Stream<Event> operator [](Type eventType) =>
      _events.where((e) => e.runtimeType == eventType);
}
