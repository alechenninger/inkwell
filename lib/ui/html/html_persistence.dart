// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:html';

import 'package:august/august.dart';

class HtmlPersistence implements Persistence {
  final String _scriptHandle;
  final _savedInteractions = <SavedInteraction>[];

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

  void saveInteraction(Duration offset, String moduleName,
      String interactionName, Map<String, dynamic> parameters) {
    var interaction =
        new SavedInteraction(moduleName, interactionName, parameters, offset);
    _savedInteractions.add(interaction);
  }

  List<SavedInteraction> get savedInteractions =>
      new List<SavedInteraction>.from(_savedInteractions);
}
