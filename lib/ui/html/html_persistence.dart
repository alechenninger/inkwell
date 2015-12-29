// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.ui.html.persistence;

import 'dart:convert';
import 'dart:html';

import 'package:august/august.dart';

class HtmlPersistence implements Persistence {
  final String _scriptHandle;
  final List<InterfaceEvent> _savedEvents = [];

  HtmlPersistence(Script script, [Storage _storage])
      : _scriptHandle = script.name + script.version {
    var storage = _storage == null ? window.localStorage : _storage;

    if (storage.containsKey(_scriptHandle)) {
      var saved = JSON.decode(storage[_scriptHandle]) as List<Map>;
      _savedEvents.addAll(saved.map((o) => new InterfaceEvent.fromJson(o)));
    }

    window.onBeforeUnload.listen((e) {
      storage[_scriptHandle] = JSON.encode(_savedEvents);
    });
  }

  void saveEvent(InterfaceEvent event) {
    _savedEvents.add(event);
  }

  List<InterfaceEvent> get savedEvents => new List.from(_savedEvents);
}
