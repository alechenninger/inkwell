// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

abstract class JsonEncodable {
  Map toJson();
}

// TODO: I think we can just use getDeserializer and not need type-specific
// revivers

class _ActorReviver {
  final Registry registry;

  _ActorReviver(this.registry);

  JsonEncodable call(key, value) {
    if (value is Map && _Decodable.isDecodable(value)) {
      var decable = new _Decodable.fromJson(value);
      if (registry.hasActor(decable.type)) {
        return registry.getActorFactory(value)(decable.json);
      }
    }

    return value;
  }
}

class _FilterReviver {
  final Registry registry;

  _FilterReviver(this.registry);

  dynamic call(key, value) {
    if (value is Map && _Decodable.isDecodable(value)) {
      var decable = new _Decodable.fromJson(value);
      if (registry.hasFilter(decable.type)) {
        return registry.getFilterFactory(value)(decable.json);
      }
    }

    return value;
  }
}

typedef dynamic Deserializer(Map json);

// TODO: better name
class _Decodable {
  final String type;
  final Map json;

  static bool isDecodable(Map json) {
    return json.containsKey(_typeKey) && json.containsKey(_jsonKey);
  }

  _Decodable(this.type, this.json);
  _Decodable.fromJson(Map json) : this(json[_typeKey], json[_jsonKey]);
  _Decodable.fromJsonEncodable(JsonEncodable encable)
      : this("$encable.runtimeType", encable.toJson());

  Map toJson() => {_typeKey: type, _jsonKey: json};

  static const String _typeKey = "_type_";
  static const String _jsonKey = "_json_";
}

dynamic _toEncodable(value) {
  if (value is JsonEncodable) {
    return new _Decodable.fromJsonEncodable(value);
  }

  return value;
}
