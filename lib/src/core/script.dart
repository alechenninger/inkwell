// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

typedef Actor ActorFactory(Game game);
typedef EventFilter FilterDeserializer(Map json);
typedef Event EventDeserializer(Map json);
typedef dynamic Deserializer(Map json);

JsonCodec getJsonCodec(Script registry) {
  return new JsonCodec(
      reviver: new _RegistryReviver(registry), toEncodable: _toEncodable);
}

abstract class Script {
  String get name;
  String get version;

  Actor getActor(String typeName, Game game);
  EventFilter getFilter(Map json);
  Event getEvent(Map json);

  void addActor(ActorFactory actor);
  void addFilter(Type type, FilterDeserializer filterFactory);
  void addEvent(Type event, EventDeserializer eventFactory);
}

abstract class JsonEncodable {
  Map toJson();
}

class _RegistryReviver {
  final Script registry;

  _RegistryReviver(this.registry);

  JsonEncodable call(key, value) {
    if (value is Map && _JsonDecodable.isDecodable(value)) {
      var decable = new _JsonDecodable.fromJson(value);
      if (registry.hasType(decable.type)) {
        return registry.getDeserializer(decable.type)(decable.json);
      }
    }

    return value;
  }
}

Map _toEncodable(value) {
  if (value is JsonEncodable) {
    return new _JsonDecodable.fromJsonEncodable(value).toJson();
  }

  return value.toJson();
}

// TODO: better name
class _JsonDecodable {
  static bool isDecodable(Map json) {
    return json.containsKey(_typeKey) && json.containsKey(_jsonKey);
  }

  final String type;
  final Map json;

  _JsonDecodable(this.type, this.json);
  _JsonDecodable.fromJson(Map json) : this(json[_typeKey], json[_jsonKey]);
  _JsonDecodable.fromJsonEncodable(JsonEncodable encable)
      : this("$encable.runtimeType", encable.toJson());

  Map toJson() => {_typeKey: type, _jsonKey: json};

  static const String _typeKey = "_type_";
  static const String _jsonKey = "_json_";
}
