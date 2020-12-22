// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:html';
import 'dart:math';

import 'package:august/ui.dart';

class HtmlArchive extends Archive {
  final String _scriptHandle;
  final Storage _storage;

  HtmlArchive(this._scriptHandle, {Storage storage})
      : _storage = storage ?? window.localStorage;

  final _versions = <String, Version>{};

  @override
  Version operator [](String version) => _versions.putIfAbsent(
      version, () => HtmlVersion(_storage, _scriptHandle, version));

  @override
  List<Version> get versions => _versions.values.toList(growable: false);

  @override
  bool remove(String version) {
    return _storage.remove(_versionKey(_scriptHandle, version)) != null;
  }

  @override
  Version newVersion() {
    return this['unnamed-${Random().nextInt(4294967296)}'];
  }
}

class HtmlVersion implements Version {
  final String _scriptHandle;
  final _savedActions = <RecordedAction>[];
  final Storage _storage;
  final String name;

  String get _key => _versionKey(_scriptHandle, name);

  static const _json = JsonCodec();

  HtmlVersion(this._storage, this._scriptHandle, this.name) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    if (!_storage.containsKey(_key)) {
      return;
    }

    var saved = _json.decode(_storage[_key]) as List<dynamic>;
    _savedActions.addAll(
        saved.map((o) => RecordedAction.fromJson(o as Map<String, Object>)));
  }

  @override
  List<RecordedAction> get actions => List<RecordedAction>.from(_savedActions);

  @override
  void record(Duration offset, Object action) {
    _savedActions.add(RecordedAction(offset, action));
    _storage[_key] = _json.encode(_savedActions);
  }
}

String _versionKey(String scriptHandle, String version) =>
    '$scriptHandle:$version';
