// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:html';

import 'package:august/august.dart';

class HtmlPersistence implements Persistence {
  final String _scriptHandle;
  final _savedInteractions = <SavedInteraction>[];
  static const _json = JsonCodec();

  HtmlPersistence(this._scriptHandle, [Storage _storage]) {
    var storage = _storage == null ? window.localStorage : _storage;

    if (storage.containsKey(_scriptHandle)) {
      var saved =
          _json.decode(storage[_scriptHandle]) as List<Map<String, Object>>;
      _savedInteractions
          .addAll(saved.map((o) => SavedInteraction.fromJson(o)));
    }

    window.onBeforeUnload.listen((e) {
      storage[_scriptHandle] = _json.encode(_savedInteractions);
    });
  }

  void saveInteraction(Duration offset, String moduleName,
      String interactionName, Map<String, dynamic> parameters) {
    var interaction =
        SavedInteraction(moduleName, interactionName, parameters, offset);
    _savedInteractions.add(interaction);
  }

  List<SavedInteraction> get savedInteractions =>
      List<SavedInteraction>.from(_savedInteractions);
}
