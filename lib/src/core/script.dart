// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

typedef Actor ActorFactory(Game game, [Map json]);
typedef EventFilter FilterDeserializer(Map json);
typedef Event EventDeserializer(Map json);

abstract class Script {
  String get name;
  String get version;

  factory Script(String name, String version) {
    return new _Script(name, version);
  }

  Map<String, Actor> getActors(Game game, [Map<String, Map> typesToJson]);
  EventFilter getFilter(String type, Map json);
  Event getEvent(String type, Map json);

  void addActor(Type actor, ActorFactory actorFactory);
  void addFilter(Type filter, FilterDeserializer filterFactory);
  void addEvent(Type event, EventDeserializer eventFactory);
}

class _Script implements Script {
  Map<String, ActorFactory> _actors;
  Map<String, EventDeserializer> _events;
  Map<String, FilterDeserializer> _filters;

  final String name;
  final String version;

  _Script(this.name, this.version);

  void addActor(Type actor, ActorFactory actorFactory) {
    _actors[actor.toString()] = actorFactory;
  }

  void addEvent(Type event, EventDeserializer eventFactory) {
    _events[event.toString()] = eventFactory;
  }

  void addFilter(Type filter, FilterDeserializer filterFactory) {
    _filters[filter.toString()] = filterFactory;
  }

  Map<String, Actor> getActors(Game game, [Map<String, Map> typesToJson]) {
    Map actors = {};
    _actors.forEach(
        (type, factory) => actors[type] = factory(game, typesToJson[type]));
    return actors;
  }

  Event getEvent(String type, Map json) {
    return _events[type](json);
  }

  EventFilter getFilter(String type, Map json) {
    return _filters[type](json);
  }
}
