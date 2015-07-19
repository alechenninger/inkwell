// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

class Subscription {
  final String id = _uuid.v4();
  final EventFilter filter;
  // TODO: lister name / actor name combo is really a type
  final String actor;
  final String listener;
  final bool persistent;

  Subscription(this.filter, this.listener, this.actor, {this.persistent: false});
  Subscription.fromJson(Map json, Script script) : this(
          script.getFilter(json["filter"]["type"], json["filter"]["data"]),
          json["listener"], json["actor"],
          persistent: json["persistent"]);

  Listener getListener(Game game) {
    return game.getActor(actor).listeners[listener];
  }

  Map toJson() => {
    "filter": {"type": filter.runtimeType, "data": filter},
    "listener": listener,
    "actor": actor,
    "persistent": persistent
  };
}

abstract class EventFilter {
  const EventFilter();

  Stream<Event> filter(Stream<Event> stream);

  EventFilter and(EventFilter additional) => new AndFilter(this, additional);
}

class AllEvents extends EventFilter {
  const AllEvents();

  Stream<Event> filter(Stream<Event> stream) {
    return stream;
  }

  Map toJson() => {};
}

class AndFilter extends EventFilter {
  final EventFilter _left;
  final EventFilter _right;

  AndFilter(this._left, this._right);

  AndFilter.fromJson(Map json, Script script)
      : _left = script.getFilter(json["left"]["type"], json["left"]["data"]),
        _right = script.getFilter(json["right"]["type"], json["right"]["data"]);

  Stream<Event> filter(Stream<Event> stream) {
    return _right.filter(_left.filter(stream));
  }

  Map toJson() => {
    "left": {"type": _left.runtimeType, "data": _left},
    "right": {"type": _right.runtimeType, "data": _right}
  };
}

// TODO: new EventName().eq("foo");
// new EventName().notEq("foo");
// new EventType().eq(DialogEvent);

class EventTypeEq extends EventFilter {
  final String _type;

  EventTypeEq(this._type);
  EventTypeEq.fromJson(Map json) : _type = json["type"];

  Stream<Event> filter(Stream<Event> stream) {
    return stream.where((e) => e.runtimeType.toString() == _type);
  }

  Map toJson() => {"type": _type};
}

class EventTargetEq extends EventFilter {
  final String _target;

  EventTargetEq(this._target);
  EventTargetEq.fromJson(Map json) : _target = json["target"];

  Stream<Event> filter(Stream<Event> stream) {
    return stream.where((e) => e.target == _target);
  }

  Map toJson() => {"target": _target};
}

Map<Type, FilterDeserializer> _defaultFilters = {
  AllEvents: (json, script) => new AllEvents(),
  AndFilter: (json, script) => new AndFilter.fromJson(json, script),
  EventTypeEq: (json, script) => new EventTypeEq.fromJson(json),
  EventTargetEq: (json, script) => new EventTargetEq.fromJson(json)
};
