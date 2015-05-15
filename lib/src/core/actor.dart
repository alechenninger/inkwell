// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

abstract class Actor extends Object with ActorSupport {
  final Game game;

  Actor(this.game);

  Map<String, Listener> get listeners;

  void onBegin();
}

abstract class ActorSupport {
  Game get game;

  SubscriptionBuilder on(Type eventType) =>
      new SubscriptionBuilder(this.runtimeType, eventType, game);

  void broadcast(Event event) => game.broadcast(event);
}

/// Responds to an [Event] occurrence. [Listener]s are actor-specific.
typedef void Listener<T>(Event event);

class SubscriptionBuilder {
  final Type actorType;
  final Type eventType;
  final Game game;

  EventFilter filter;

  SubscriptionBuilder(this.actorType, this.eventType, this.game) {
    filter = new EventTypeEq(eventType.toString());
  }

  void listen(String listener) {
    game.subscribe(listener, actorType, filter: filter);
  }
}

abstract class ListenerType {
  String get name;
  Listener get listener;
}
