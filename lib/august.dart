// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august;

import 'dart:async';
import 'dart:math';

import 'package:built_value/serializer.dart';
import 'package:quiver/time.dart';
import 'package:rxdart/rxdart.dart';

import 'src/core.dart';
import 'src/event_stream.dart';
import 'src/pausable.dart';
import 'src/persistence.dart';
import 'ui.dart';

export 'dart:async';

export 'src/core.dart';
export 'src/observable.dart';
export 'src/persistence.dart';
export 'src/scope.dart';
export 'ui.dart';

void play(void Function() story, SaveSlot persistence, UserInterface ui,
    Set<StoryModule> modules,
    {Stopwatch stopwatch}) {
  stopwatch ??= Stopwatch();
  var fastForwardZone = FastForwarder(() => stopwatch.elapsed);
  var pausableZone = PausableZone(() => stopwatch.elapsed);

  var modulesByType = modules.fold<Map<Type, StoryModule>>(
      <Type, StoryModule>{},
      (map, module) => map..[module.runtimeType] = module);

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

  @override
  // TODO: implement metaActions
  Stream<MetaAction> get metaActions => throw UnimplementedError();
}

Future delay({int seconds}) {
  return Future.delayed(Duration(seconds: seconds));
}

// Narrator?
class StoryTeller {
  final Script _script;
  final Saver _saver;
  final Stopwatch _stopwatch;
  final Random _random;
  final UserInterface _ui;
  final ModuleSet Function() _newModuleSet;

  StoryTeller._(this._script, this._saver, this._stopwatch, this._random,
      this._newModuleSet, this._ui) {
    // TODO: listen to meta actions
  }

  Story start() {
    var modules = _newModuleSet();
    // TODO: UI can only handle one story. needs to also have a "reset"
    /*
    Order:
    1. start/continue
    2. then add pause/resume
    3. then add start new – will require closing out current story / resetting
    4. then add save to/load from save slots – will require notion of different
    save slots as well as resets from 3.
     */
    _ui.play(modules.events);
    return Story._('1', _script, modules, _stopwatch, _ui.actions);
  }

  Story load(String save) {}

  List<String> saves() {}
}

class Story {
  final String storyId;
  final Script _script;
  final PausableZone _pausableZone;
  final ModuleSet _modules;
  final Stream<Action> _actions;

  Story._(this.storyId, this._script, this._modules, Stopwatch stopwatch,
      this._actions)
      : _pausableZone = PausableZone(() => stopwatch.elapsed) {
    // TODO: look into saveslot/saver model more
    _start(NoPersistence());
  }

  void _start(SaveSlot save) {
    var fastForwarder = FastForwarder(() => _pausableZone.offset);
    var replayedActions = StreamController<Action>(sync: true);

    var actions = Rx.concat([
      replayedActions.stream,
      _actions.doOnData((action) {
        var serialized = _modules.serializers.serialize(action);
        // TODO: are there race conditions here?
        // At this offset this may persist, but not actually succeed to run by the
        // time it's run (is this possible?)
        // What about if it succeeds inn the run, but not when replayed?
        save.saveAction(fastForwarder.currentOffset, serialized);
      })
    ]);

    _pausableZone.run((c) {
      fastForwarder.runFastForwardable((ff) {
        actions.listen((action) {
          print('action: ${fastForwarder.currentOffset} $action');
          action.run(_modules[action.module]);
        });

        _script(_modules);

        var savedActions = save.actions;

        if (savedActions.isEmpty) {
          replayedActions.close();
        } else {
          // TODO: could publish a "loading" event here so UI can react to all the
          // rapid-fire events accordingly
          for (var i = 0; i < savedActions.length; i++) {
            var saved = savedActions[i];
            Future.delayed(saved.offset, () {
              var action =
                  _modules.serializers.deserialize(saved.action) as Action;
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

  void checkpoint() {}

  void changeSlot(String save) {
    // would have to copy all actions to new save slot
    // probably needs to happen at Saver level somewhat
  }

  void pause() {
    _pausableZone.pause();
  }

  void resume() {
    _pausableZone.resume();
  }
}

typedef Script = void Function(ModuleSet);

// Inkwell ? Quill?
class ModuleSet extends StoryModule {
  Map<Type, StoryModule> _byType;
  Stream<Event> _events;
  Serializers _serializers;

  ModuleSet(Iterable<StoryModule> m) {
    // TODO: validate that no two modules share the same type
    _byType = m.fold<Map<Type, StoryModule>>(<Type, StoryModule>{},
        (map, module) => map..[module.runtimeType] = module);
    _events = Rx.merge(values.map((m) => m.events)).asBroadcastStream();
    _serializers = Serializers.merge(values.map((m) => m.serializers));
  }

  T call<T>() => _byType[T] as T;

  StoryModule operator [](Type t) => _byType[t];

  Iterable<StoryModule> get values => _byType.values;

  @override
  Stream<Event> get events => _events;

  @override
  Serializers get serializers => _serializers;
}

// TODO: better name
abstract class MetaAction {
  void run(StoryTeller t);
}

class StartStory extends MetaAction {
  @override
  void run(StoryTeller t) {
    t.start();
  }

}
