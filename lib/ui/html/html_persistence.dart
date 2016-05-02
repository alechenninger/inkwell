// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.ui.html.persistence;

import 'dart:convert';
import 'dart:html';

import 'package:august/august.dart';

class HtmlPersistence implements Persistence {
  final String _scriptHandle;
  final List<SavedInteraction> _savedInteractions = [];

  HtmlPersistence(this._scriptHandle, [Storage _storage]) {
    var storage = _storage == null ? window.localStorage : _storage;

    if (storage.containsKey(_scriptHandle)) {
      var saved = JSON.decode(storage[_scriptHandle]) as List<Map>;
      _savedInteractions
          .addAll(saved.map((o) => new SavedInteraction.fromJson(o)));
    }

    window.onBeforeUnload.listen((e) {
      storage[_scriptHandle] = JSON.encode(_savedInteractions);
    });
  }

  void saveEvent(Duration offset, String moduleName, String actionType,
      Map<String, dynamic> args) {
    var interaction =
        new SavedInteraction(moduleName, actionType, args, offset);
    _savedInteractions.add(interaction);
  }

  List<SavedInteraction> get savedInteractions =>
      new List.from(_savedInteractions);
}
