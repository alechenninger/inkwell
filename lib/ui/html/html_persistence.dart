// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:html';

import 'package:august/august.dart';

class HtmlArchive extends Archive {
  final String _scriptHandle;
  final Storage _storage;

  static const _json = JsonCodec();

  HtmlArchive(this._scriptHandle, {Storage storage})
      : _storage = storage ?? window.localStorage;

  @override
  Version operator [](String version) => _loadFromStorage(version);

  @override
  List<Version> get versions => _storage.keys
      .where((element) => element.startsWith('$_scriptHandle:'))
      .map((e) => _loadFromStorage(e.substring('$_scriptHandle:'.length)))
      .toList(growable: false);

  @override
  bool remove(String version) {
    return _storage.remove(_versionKey(_scriptHandle, version)) != null;
  }

  @override
  void save(Version version) {
    _storage[_versionKey(_scriptHandle, version.name)] =
        _json.encode(version.actions);
  }

  @override
  void append(List<OffsetAction> actions, String version) {
    // TODO: implement append
  }

  Version _loadFromStorage(String version) {
    var key = _versionKey(_scriptHandle, version);
    if (!_storage.containsKey(key)) {
      return null;
    }

    var saved = _json.decode(_storage[key]) as List<dynamic>;
    return Version.started(
        version,
        saved
            .map((o) => OffsetAction.fromJson(o as Map<String, Object>))
            .toList());
  }
}

String _versionKey(String scriptHandle, String version) =>
    '$scriptHandle:$version';
