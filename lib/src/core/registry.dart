// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

abstract class Registry {
  factory Registry() {
    return new _Registry();
  }

  bool hasType(dynamic type);
  bool hasActor(dynamic type);
  bool hasFilter(dynamic type);

  Deserializer getDeserializer(dynamic type);
  ActorFactory getActorFactory(dynamic type);
  FilterFactory getFilterFactory(dynamic type);
  Listener getListener(String name, dynamic actorType);

  void registerType(String key, Deserializer deserializer);
  void registerActor(
      Type type, CreateActor createActor, RecreateActor recreateActor);
  void registerListener(String name, Type actorType, Listener listener);
  void registerFilter(Type type, FilterFactory filterFactory);
}

class _Registry implements Registry {
  final Map<String, Deserializer> _deserializers = {};

  /// Map of actor names to map of listener names to [Listener] function. In
  /// other words, listeners are scoped to a specific actor.
  final Map<String, Map<String, Listener>> _listeners = {};

  void registerType(dynamic type, Deserializer deserializer) {
    _deserializers["$type"] = deserializer;
  }

  void registerActor(
      Type type, CreateActor createActor, RecreateActor recreateActor) {
    _deserializers[_actorType(type)] =
        new ActorFactory(createActor, recreateActor);
  }

  // TODO: Include listeners in actor registration?
  void registerListener(String name, Type actorType, Listener onEvent) {
    _listeners.putIfAbsent("$actorType", () => {});
    _listeners["$actorType"][name] = onEvent;
  }

  void registerFilter(Type type, FilterFactory filterFactory) {
    _deserializers[_filterType(type)] = filterFactory;
  }

  bool hasType(type) => _deserializers.containsKey("$type");

  bool hasActor(type) => hasType(_actorType(type));

  bool hasFilter(type) => hasType(_filterType(type));

  Deserializer getDeserializer(type) => _deserializers["$type"];

  ActorFactory getActorFactory(type) =>
      _deserializers[_actorType(type)] as ActorFactory;

  FilterFactory getFilterFactory(type) => _deserializers[_filterType(type)];

  Listener getListener(String name, type) => _listeners["$type"][name];

  String _actorType(dynamic type) => "actor|$type";
  String _filterType(dynamic type) => "filter|$type";
}

/// Creates an actor with its initial state.
typedef JsonEncodable CreateActor();

/// Recreates an actor from a previous saved state.
typedef JsonEncodable RecreateActor(Map json);

/// Responds to an [Event] occurance. [Listener]s are actor-specific.
typedef void Listener(Event event, dynamic actor, Game game);

typedef EventFilter FilterFactory(Map json);

class ActorFactory<T extends JsonEncodable> {
  final CreateActor createActor;
  final RecreateActor recreateActor;

  ActorFactory(this.createActor, this.recreateActor);

  T call([Map json]) {
    return json == null ? createActor() : recreateActor(json);
  }
}
