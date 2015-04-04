// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

abstract class SimpleActor implements JsonEncodable {
  final Map<String, dynamic> _attributes;

  SimpleActor.fromJson(this._attributes);

  dynamic operator [](String attribute) => _attributes[attribute];
  void operator []=(String attribute, JsonEncodable value) {
    _attributes[attribute] = value;
  }

  String toString() => toJson().toString();

  @override
  Map toJson() => new Map.from(_attributes);
}
