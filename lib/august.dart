// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august;

import 'dart:async';

import 'package:built_value/serializer.dart';
import 'package:quiver/time.dart';
import 'package:rxdart/rxdart.dart';

import 'src/core.dart';
import 'src/event_stream.dart';
import 'src/persistence.dart';
import 'ui.dart';

export 'dart:async';

export 'src/core.dart';
export 'src/observable.dart';
export 'src/persistence.dart';
export 'src/scope.dart';
export 'ui.dart';

void play(
  void Function() story,
  Persistence persistence,
  UserInterface ui,
  Set<StoryModule> modules,
) {
  var modulesByType = modules.fold<Map<Type, StoryModule>>(
      <Type, StoryModule>{},
      (map, module) =>
          map..[module.runtimeType] = module);
  var fastForwarder = FastForwarder(Clock());
  var events = Rx.merge(modules.map((m) => m.events)).asBroadcastStream();
  events.listen((event) => print('${fastForwarder.currentOffset} $event'));
  var serializers = Serializers.merge(modules.map((m) => m.serializers));

  var replayedActions = StreamController<Action>(sync: true);

  var actions = Rx.concat([
    replayedActions.stream,
    ui.actions.doOnData((action) {
      var serialized = serializers.serialize(action);
      // TODO: are there race conditions here?
      // At this offset this may persist, but not actually succeed to run by the
      // time it's run (is this possible?)
      // What about if it succeeds inn the run, but not when replayed?
      persistence.saveAction(fastForwarder.currentOffset, serialized);
    })
  ]);

  ui.play(events);

  fastForwarder.runFastForwardable((ff) {
    actions.listen((action) {
      print(action);
      action.run(modulesByType[action.module]);
    });

    story();

    var savedActions = persistence.actions;

    if (savedActions.isEmpty) {
      replayedActions.close();
    } else {
      // TODO: could publish a "loading" event here so UI can react to all the
      // rapid-fire events accordingly
      for (var i = 0; i < savedActions.length; i++) {
        var saved = savedActions[i];
        Future.delayed(saved.offset, () {
          var action = serializers.deserialize(saved.action) as Action;
          replayedActions.add(action);
          if (i == savedActions.length - 1) {
            replayedActions.close();
          }
        });
      }

      ff.fastForward(savedActions.last.offset);
    }
  });
}

class RemoteUserInterface implements UserInterface {
  final Serializers _serializers;

  RemoteUserInterface(this._serializers);

  @override
  // TODO: receive over the wire, deserialize
  Stream<Action> get actions => throw UnimplementedError();

  @override
  void play(Stream<Event> events) {
    // Serialize and send over the wire
  }

}

Future delay({int seconds}) {
  return Future.delayed(Duration(seconds: seconds));
}
