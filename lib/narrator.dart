library august.narrator;

import 'dart:async';
import 'dart:math';

import 'package:rxdart/rxdart.dart';

import 'src/core.dart';
import 'src/pausable.dart';
import 'src/persistence.dart';
import 'ui.dart';

// Narrator?
class Narrator {
  final Script _script;
  final Scribe _scribe;

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

  Narrator(this._script, this._scribe, this._stopwatch, this._random,
      this._clearPalette, this._ui) {
    _ui.interrupts.listen((event) {
      event.run(this);
    });
  }

  void start() async {
    await stop();

    var palette = _clearPalette();
    _ui.play(Rx.merge([_directorEvents.stream, palette.events]));
    _story = Story._('1', _script, palette, _stopwatch, _ui.actions);
  }

  void load(String save) {}

  Future stop() async {
    if (_story == null) {
      return Future.sync(() {});
    }

    _story.close();
    _directorEvents.close();
    await _ui.stopped;
    _directorEvents = StreamController<Event>();
  }

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

  Story._(
      this.storyId, this._script, this._palette, this._stopwatch, this._actions)
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
