// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.core;

import 'package:quiver/check.dart';

import 'dart:async';
export 'dart:async';

typedef Future<Event> Once(dynamic event);
typedef Stream<Event> Every(dynamic event);
typedef Future<Event> Emit(Event event);
typedef void RunScript(Once once, Options options, Emit emit);

class Script {
  final String name;
  final String version;
  final RunScript run;

  Script(this.name, this.version, this.run);
}

class Event {
  final String name;

  Event(this.name);
}

class Run {
  final Script _script;

  Run(this._script);

  void start() {
    StreamController<Event> _ctrl =
        new StreamController.broadcast(sync: true);

    Future<Event> once(String eventName) {
      return _ctrl.stream
          .firstWhere((e) => e.name == eventName);
    }

    Stream<Event> every(String eventName) {
      return _ctrl.stream.where((e) => e.name == eventName);
    }

    _script.run(once, new Options(), (event) {
      _ctrl.add(event);
      return new Future(() => event);
    });
  }
}

class Options {
  Set _opts = new Set();

  void add(String option) {
    _opts.add(option);
  }

  void remove(String option) {
    _opts.remove(option);
  }

  Set<String> get all => new Set.from(_opts);
}
