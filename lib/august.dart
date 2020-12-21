// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august;

import 'dart:async';
import 'dart:math';

import 'package:august/ui/html/html_persistence.dart';
import 'package:built_value/serializer.dart';
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
  Future play(Stream<Event> events) {}

  @override
  // TODO: implement metaActions
  Stream<MetaAction> get metaActions => throw UnimplementedError();

  @override
  // TODO: implement stopped
  Future get stopped => throw UnimplementedError();
}

Future delay({int seconds}) {
  return Future.delayed(Duration(seconds: seconds));
}

// Narrator?
class StoryTeller {
  final Script _script;
  final Saver _saver;
  // TODO: need to be Stopwatch f() if we want to manage multiple stories
  final Stopwatch _stopwatch;
  final Random _random;
  final UserInterface _ui;
  final ModuleSet Function() _newModuleSet;

  // TODO: Could have server support multiple?
  // Would this require separate isolates for each?
  // Or does it matter that microtasks and events would interleave?
  // I don't believe it should, technically, since each story itself would still
  // be ordered.
  Story _story;
  // This is handled a bit ugly. Maybe it makes sense a part of Story?
  var _tellerEvents = StreamController<Event>();

  StoryTeller(this._script, this._saver, this._stopwatch, this._random,
      this._newModuleSet, this._ui) {
    _ui.metaActions.listen((event) {
      event.run(this);
    });
  }

  void start() async {
    if (_story != null) {
      _story.close();
      _tellerEvents.close();
      await _ui.stopped;
      _tellerEvents = StreamController<Event>();
    }

    var modules = _newModuleSet();
    _ui.play(Rx.merge([_tellerEvents.stream, modules.events]));
    _story = Story._('1', _script, modules, _stopwatch, _ui.actions);
  }

  void load(String save) {}

  List<String> saves() {}
}

class Story {
  final String storyId;
  final Script _script;
  final PausableZone _pausableZone;
  final ModuleSet _modules;
  final Stream<Action> _actions;

  StreamSubscription _actionsSubscription;

  Story._(this.storyId, this._script, this._modules, Stopwatch stopwatch,
      this._actions)
      : _pausableZone = PausableZone(() => stopwatch.elapsed) {
    // TODO: look into saveslot/saver model more
    stopwatch.start();
    _start(NoPersistence());
  }

  void _start(SaveSlot save) {
    var fastForwarder = FastForwarder(() => _pausableZone.offset);
    var replayedActions = StreamController<Action>(sync: true);

    // TODO: move this?
    _modules.events.listen(
        (event) => print('event: ${fastForwarder.currentOffset} $event'));

    var actions = Rx.concat([
      replayedActions.stream,
      _actions.where((action) {
        if (_pausableZone.isPaused) {
          // TODO: emit error somehow?
          print('caught action while paused, ignoring. action=$action');
          return false;
        }
        return true;
      }).doOnData((action) {
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
        _actionsSubscription = actions.listen((action) {
          print('action: ${fastForwarder.currentOffset} $action');
          // TODO: move saving here; detect if ff-ing and don't save in that
          //  case?
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
    print('paused');
  }

  void resume() {
    _pausableZone.resume();
    print('resumed');
  }

  Future close() =>
      Future.wait([_modules.close(), _actionsSubscription.cancel()]);
}

typedef Script = void Function(ModuleSet);

// Inkwell ? Quill?
class ModuleSet {
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

  Stream<Event> get events => _events;

  Serializers get serializers => _serializers;

  Future close() => Future.wait(values.map((m) => m.close()));
}

// TODO: better name
abstract class MetaAction {
  void run(StoryTeller t);
}

// TODO: serializable

class StartStory extends MetaAction {
  @override
  void run(StoryTeller t) {
    t.start();
  }
}

class PauseStory extends MetaAction {
  @override
  void run(StoryTeller t) {
    if (t._story == null) {
      t._tellerEvents.addError(
          StateError("can't pause story; no story is currently being told."));
      return;
    }
    t._story.pause();
  }
}

class ResumeStory extends MetaAction {
  @override
  void run(StoryTeller t) {
    if (t._story == null) {
      t._tellerEvents.addError(
          StateError("can't resume story; no story is currently being told."));
      return;
    }
    t._story.resume();
  }
}
