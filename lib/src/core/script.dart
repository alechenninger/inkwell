// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

typedef Actor ActorFactory(Game game, Script script, [Map json]);
typedef EventFilter FilterDeserializer(Map json);
typedef Event EventDeserializer(Map json, Script script);

/// [Script]s are immutable and accept all of their details in their
/// constructor. This builder exists to make constructing such a `Script` more
/// convenient.
class ScriptBuilder {
  Map<String, ActorFactory> _actors = {};
  Map<String, EventDeserializer> _events = {};
  Map<String, FilterDeserializer> _filters = {};

  ScriptBuilder() {
    _defaultEvents.forEach(addEvent);
    _defaultFilters.forEach(addFilter);
  }

  void addActor(Type actor, ActorFactory actorFactory) {
    _actors[actor.toString()] = actorFactory;
  }

  void addEvent(Type event, EventDeserializer eventFactory) {
    _events[event.toString()] = eventFactory;
  }

  void addFilter(Type filter, FilterDeserializer filterFactory) {
    _filters[filter.toString()] = filterFactory;
  }

  Script build(String name, String version) =>
      new _Script(name, version, _actors, _events, _filters);
}

/// Houses the means of creating (or recreating from stored JSON) all of the
/// elements of your story: the [Actor]s, which make up the
/// central bodies of state and origin of events, [Event]s of various types,
/// which carry state and can be listened to by `Actor`s, and [EventFilter]s
/// which are the conditions about which an `Actor`'s listener will be
/// executed.
abstract class Script {
  String get name;
  String get version;

  Map<String, Actor> getActors(Game game, [Map<String, Map> typesToJson]);
  EventFilter getFilter(String type, Map json);
  Event getEvent(String type, Map json);
}

class _Script implements Script {
  Map<String, ActorFactory> _actors;
  Map<String, EventDeserializer> _events;
  Map<String, FilterDeserializer> _filters;

  final String name;
  final String version;

  _Script(this.name, this.version, this._actors, this._events, this._filters);

  Map<String, Actor> getActors(Game game, [Map typesToJson = const {}]) {
    var actors = {};

    _actors.forEach((type, factory) =>
        actors[type] = factory(game, this, typesToJson[type]));

    return actors;
  }

  Event getEvent(String type, Map json) {
    return _events[type](json, this);
  }

  EventFilter getFilter(String type, Map json) {
    return _filters[type](json);
  }
}
