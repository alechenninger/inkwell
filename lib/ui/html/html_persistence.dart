// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:html';

import '../../src/persistence.dart';

class HtmlPersistence implements Persistence {
  final String _scriptHandle;
  final _savedInteractions = <SavedAction>[];
  Storage _storage;

  static const _json = JsonCodec();

  HtmlPersistence(this._scriptHandle, [Storage _storage]) {
    this._storage = _storage ?? window.localStorage;

    if (_storage.containsKey(_scriptHandle)) {
      var saved =
          _json.decode(_storage[_scriptHandle]) as List<Map<String, Object>>;
      _savedInteractions
          .addAll(saved.map((o) => SavedAction.fromJson(o)));
    }

    window.onBeforeUnload.listen((e) {
      _storage[_scriptHandle] = _json.encode(_savedInteractions);
    });
  }

  void clear() {
    _storage.remove(_scriptHandle);
  }

  void saveInteraction(Duration offset, String moduleName,
      String interactionName, Map<String, dynamic> parameters) {
    var interaction =
        SavedAction(moduleName, interactionName, parameters, offset);
    _savedInteractions.add(interaction);
  }

  List<SavedAction> get savedInteractions =>
      List<SavedAction>.from(_savedInteractions);
}
