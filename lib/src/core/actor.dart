// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

abstract class Actor {
  Map<String, Listener> get listeners;

  void onBegin();
}

abstract class ActorSupport implements Actor {
  final Game game;

  ActorSupport(this.game);

  SubscriptionBuilder on(Type eventType) =>
      new SubscriptionBuilder(this.runtimeType, eventType, game);

  void broadcast(Event event) => game.broadcast(event);

  void broadcastDelayed(Duration delay, Event event) =>
      game.broadcastDelayed(delay, event);

  void addOption(Option option) => game.addOption(option);
}

/// Responds to an [Event] occurrence. [Listener]s are actor-specific.
typedef void Listener<T>(Event event);

class SubscriptionBuilder {
  final Type actorType;
  final Type eventType;
  final Game game;

  EventFilter _filter;
  bool _persistent = false;

  SubscriptionBuilder(this.actorType, this.eventType, this.game) {
    _filter = new EventTypeEq(eventType.toString());
  }

  void where(EventFilter filter) {
    _filter = _filter.and(filter);
  }

  void persistently() {
    _persistent = true;
  }

  void listen(String listener) {
    game.subscribe(listener, actorType, filter: _filter, persistent: _persistent);
  }
}

abstract class ListenerType {
  String get name;
  Listener get listener;
}
