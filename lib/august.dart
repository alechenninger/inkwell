// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august;

import 'dart:async';

import 'package:august/ui.dart';
import 'package:built_value/serializer.dart';
import 'package:quiver/time.dart';
import 'package:rxdart/rxdart.dart';

import 'input.dart';
import 'module.dart';
import 'src/persistence.dart';
import 'ui.dart';

export 'dart:async';

export 'input.dart';
export 'module.dart';
export 'src/observable.dart';
export 'src/persistence.dart';
export 'src/scope.dart';
export 'src/story.dart';

void play(
  void Function() story,
  Persistence persistence,
  UserInterface ui,
  Set<Module> modules,
) {
  var modulesByType = modules.fold<Map<Type, dynamic>>(
      <Type, dynamic>{},
      (previousValue, element) =>
          previousValue..[element.runtimeType] = element);
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
      action.run(modulesByType[action.module]);
    });

    story();

    var saved = persistence.actions;

    if (saved.isEmpty) {
      replayedActions.close();
    } else {
      // TODO: could publish a "loading" event here so UI can react to all the
      // rapid-fire events accordingly
      for (var i = 0; i < saved.length; i++) {
        var a = saved[i];
        Future.delayed(a.offset, () {
          var action = serializers.deserialize(a.action) as Action;
          replayedActions.add(action);
          if (i == saved.length - 1) {
            replayedActions.close();
          }
        });
      }

      ff.fastForward(saved.last.offset);
    }
  });
}
