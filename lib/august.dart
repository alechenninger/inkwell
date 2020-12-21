// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august;

import 'dart:async';

import 'package:built_value/serializer.dart';
import 'package:rxdart/rxdart.dart';

import 'src/core.dart';
import 'src/event_stream.dart';
import 'src/pausable.dart';
import 'src/persistence.dart';
import 'ui.dart';

export 'dart:async';

export 'narrator.dart';
export 'src/core.dart';
export 'src/observable.dart';
export 'src/persistence.dart';
export 'src/scope.dart';
export 'ui.dart';

void play(void Function() story, Chronicle persistence, UserInterface ui,
    Set<Ink> modules,
    {Stopwatch stopwatch}) {
  stopwatch ??= Stopwatch();
  var fastForwardZone = FastForwarder(() => stopwatch.elapsed);
  var pausableZone = PausableZone(() => stopwatch.elapsed);

  var modulesByType = modules.fold<Map<Type, Ink>>(
      <Type, Ink>{}, (map, module) => map..[module.runtimeType] = module);

  var events = Rx.merge(modules.map((m) => m.events)).asBroadcastStream();
  events.listen(
      (event) => print('event: ${fastForwardZone.currentOffset} $event'));
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
      persistence.saveAction(fastForwardZone.currentOffset, serialized);
    })
  ]);

  ui.play(events);

  pausableZone.run((c) {
    fastForwardZone.runFastForwardable((ff) {
      actions.listen((action) {
        print('action: ${fastForwardZone.currentOffset} $action');
        action.perform(modulesByType[action.ink]);
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
  });
}

Future delay({int seconds}) {
  return Future.delayed(Duration(seconds: seconds));
}
