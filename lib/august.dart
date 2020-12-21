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

void play(void Function() story, Chronicle persistence, UserInterface ui,
    Set<Ink> modules,
    {Stopwatch stopwatch}) {
  stopwatch ??= Stopwatch();
  var fastForwardZone = FastForwarder(() => stopwatch.elapsed);
  var pausableZone = PausableZone(() => stopwatch.elapsed);

  var modulesByType = modules.fold<Map<Type, Ink>>(
      <Type, Ink>{},
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
  Stream<Interrupt> get interrupts => throw UnimplementedError();

  @override
  // TODO: implement stopped
  Future get stopped => throw UnimplementedError();
}

Future delay({int seconds}) {
  return Future.delayed(Duration(seconds: seconds));
}

// Narrator?
class Narrator {
  final Script _script;
  final Scribe _saver;
  // TODO: need to be Stopwatch f() if we want to manage multiple stories
  final Stopwatch _stopwatch;
  final Random _random;
  final UserInterface _ui;
  final Palette Function() _clearPalette;

  // TODO: Could have server support multiple?
  // Would this require separate isolates for each?
  // Or does it matter that microtasks and events would interleave?
  // I don't believe it should, technically, since each story itself would still
  // be ordered.
  Story _story;
  // This is handled a bit ugly. Maybe it makes sense a part of Story?
  var _directorEvents = StreamController<Event>();

  Narrator(this._script, this._saver, this._stopwatch, this._random,
      this._clearPalette, this._ui) {
    _ui.interrupts.listen((event) {
      event.run(this);
    });
  }

  void start() async {
    if (_story != null) {
      _story.close();
      _directorEvents.close();
      await _ui.stopped;
      _directorEvents = StreamController<Event>();
    }

    var palette = _clearPalette();
    _ui.play(Rx.merge([_directorEvents.stream, palette.events]));
    _story = Story._('1', _script, palette, _stopwatch, _ui.actions);
  }

  void load(String save) {}

  List<String> saves() {}
}

class Story {
  final String storyId;
  final Script _script;
  final PausableZone _pausableZone;
  final Palette _palette;
  final Stream<Action> _actions;
  final Stopwatch _stopwatch;

  StreamSubscription _actionsSubscription;

  Story._(this.storyId, this._script, this._palette, this._stopwatch,
      this._actions)
      : _pausableZone = PausableZone(() => _stopwatch.elapsed) {
    // TODO: look into saveslot/saver model more
    _stopwatch.start();
    _start(NoPersistence());
  }

  void _start(Chronicle save) {
    var fastForwarder = FastForwarder(() => _pausableZone.offset);
    var replayedActions = StreamController<Action>(sync: true);

    // TODO: move this?
    _palette.events.listen(
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
        var serialized = _palette.serializers.serialize(action);
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
          action.perform(_palette[action.ink]);
        });

        _script(_palette);

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
                  _palette.serializers.deserialize(saved.action) as Action;
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

  Future close() {
    _stopwatch.stop();
    _stopwatch.reset();
    return Future.wait([_palette.close(), _actionsSubscription.cancel()]);
  }
}

typedef Script = void Function(Palette);

/// A complete and useful aggregate of [Ink]s used for writing scripts.
///
/// Various [Ink]s (and their functionality) can be accessed by type by calling
/// the Palette as a generic function, e.g. `palette<Dialog>()`
///
/// The events produced by [Ink]s are accessible from the [events] broadcast
/// stream.
class Palette {
  Map<Type, Ink> _inks;
  Stream<Event> _events;
  Serializers _serializers;

  Palette(Iterable<Ink> m) {
    // TODO: validate that no two inks share the same type
    _inks = m.fold<Map<Type, Ink>>(<Type, Ink>{},
        (map, ink) => map..[ink.runtimeType] = ink);
    _events = Rx.merge(inks.map((m) => m.events)).asBroadcastStream();
    _serializers = Serializers.merge(inks.map((m) => m.serializers));
  }

  T call<T>() => _inks[T] as T;

  Ink operator [](Type t) => _inks[t];

  Iterable<Ink> get inks => _inks.values;

  Stream<Event> get events => _events;

  Serializers get serializers => _serializers;

  Future close() => Future.wait(inks.map((m) => m.close()));
}

/// A request to alter the flow or lifecycle of the narration (e.g. to start or
/// stop).
///
/// As opposed to an [Action], it is not a user interaction that is part of the
/// story; it is about the telling or playing of the story itself.
abstract class Interrupt {
  void run(Narrator t);
}

// TODO: serializable

class StartStory extends Interrupt {
  @override
  void run(Narrator t) {
    t.start();
  }
}

class PauseStory extends Interrupt {
  @override
  void run(Narrator t) {
    if (t._story == null) {
      t._directorEvents.addError(
          StateError("can't pause story; no story is currently being told."));
      return;
    }
    t._story.pause();
  }
}

class ResumeStory extends Interrupt {
  @override
  void run(Narrator t) {
    if (t._story == null) {
      t._directorEvents.addError(
          StateError("can't resume story; no story is currently being told."));
      return;
    }
    t._story.resume();
  }
}
