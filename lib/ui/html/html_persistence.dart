// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:html';

import '../../src/persistence.dart';

class HtmlPersistence implements Persistence {
  final String _scriptHandle;
  final _savedActions = <SavedAction>[];
  Storage _storage;

  static const _json = JsonCodec();

  HtmlPersistence(this._scriptHandle, [Storage _storage]) {
    this._storage = _storage ?? window.localStorage;

    if (this._storage.containsKey(_scriptHandle)) {
      var saved = _json.decode(this._storage[_scriptHandle]) as List<dynamic>;
      _savedActions.addAll(
          saved.map((o) => SavedAction.fromJson(o as Map<String, Object>)));
    }

//    window.onBeforeUnload.listen((e) {
//      this._storage[_scriptHandle] = _json.encode(_savedActions);
//    });
  }

  void clear() {
    _storage.remove(_scriptHandle);
  }

  @override
  List<SavedAction> get actions => List<SavedAction>.from(_savedActions);

  @override
  void saveAction(Duration offset, Object action) {
    _savedActions.add(SavedAction(offset, action));
    _storage[_scriptHandle] = _json.encode(_savedActions);
  }
}
