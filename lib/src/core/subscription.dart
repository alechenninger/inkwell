// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

class Subscription implements JsonEncodable {
  final String id = _uuid.v4();
  final EventFilter filter;
  // TODO: lister name / actor name combo is really a type
  final String actor;
  final String listener;

  Subscription(this.filter, this.listener, this.actor);
  Subscription.fromJson(Map json, Script script) : this(
          script.getFilter(json["filter"]), json["listener"], json["actor"]);

  Listener getListener(Game game, Script script) {
    return script.getActor(actor, game).listeners[listener];
  }

  Map toJson() => {"filter": filter, "listener": listener, "actor": actor};
}

abstract class EventFilter implements JsonEncodable {
  Stream<Event> filter(Stream<Event> stream);
}

class AllEvents implements EventFilter {
  const AllEvents();

  Stream<Event> filter(Stream<Event> stream) {
    return stream;
  }

  @override
  Map toJson() => {};
}

// TODO: new EventName().eq("foo");
// new EventName().notEq("foo");
// new EventType().eq(DialogEvent);

class EventTypeEq implements EventFilter {
  final Type _type;

  EventTypeEq(this._type);

  Stream<Event> filter(Stream<Event> stream) {
    return stream.where((e) => e.runtimeType == _type);
  }

  Map toJson() => {"type": _type};
}

class EventTargetEq implements EventFilter {
  final String _target;

  EventTargetEq(this._target);

  Stream<Event> filter(Stream<Event> stream) {
    return stream.where((e) => e.target == _target);
  }

  Map toJson() => {"target": _target};
}
