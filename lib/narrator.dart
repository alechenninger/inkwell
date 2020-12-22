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
  final Archive _archive;

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
  StreamController<Event> _directorEvents;

  Narrator(this._script, this._archive, this._stopwatch, this._random,
      this._clearPalette, this._ui) {
    _ui.interrupts.listen((event) {
      event.run(this);
    });
  }

  Future start() async {
    await stop();

    var palette = _clearPalette();
    var version = _archive.newVersion();
    _directorEvents = StreamController<Event>();
    _ui.play(Rx.merge([_directorEvents.stream, palette.events]));
    _story = Story('1', _script, palette, _stopwatch, _ui.actions, version);
  }

  Future load(String save) {}

  Future stop() async {
    if (_story == null) {
      return Future.sync(() {});
    }

    await _story.close();
    await _directorEvents?.close();
    await _ui.stopped;
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

  Story(this.storyId, this._script, this._palette, this._stopwatch,
      this._actions, Version version)
      : _pausableZone = PausableZone(() => _stopwatch.elapsed) {
    // TODO: look into saveslot/saver model more
    _stopwatch.start();
    _start(version);
    ;
  }

  void _start(Version version) {
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
        version.record(fastForwarder.currentOffset, serialized);
      })
    ]);

    _pausableZone.run((c) {
      fastForwarder.runFastForwardable((ff) {
        _actionsSubscription = actions.listen((action) {
          print('action: ${fastForwarder.currentOffset} $action');
          // TODO: move saving here; detect if ff-ing and don't save in that
          //  case?
          action.perform(_palette[action.inkType]);
        });

        _script(_palette);

        // TODO: could publish a "loading" event here so UI can react to all the
        // rapid-fire events accordingly
        var record = version.actions;
        var lastOffset = Duration.zero;

        for (var recorded in record) {
          Future.delayed(lastOffset = recorded.offset, () {
            var action =
                _palette.serializers.deserialize(recorded.action) as Action;
            replayedActions.add(action);
          });
        }

        Future.delayed(lastOffset, () => replayedActions.close());

        ff.fastForward(lastOffset);
      });
    });
  }

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
  void run(Narrator n) {
    n.start();
  }
}

class PauseStory extends Interrupt {
  @override
  void run(Narrator n) {
    if (n._story == null) {
      n._directorEvents.addError(
          StateError("can't pause story; no story is currently being told."));
      return;
    }
    n._story.pause();
  }
}

class ResumeStory extends Interrupt {
  @override
  void run(Narrator n) {
    if (n._story == null) {
      n._directorEvents.addError(
          StateError("can't resume story; no story is currently being told."));
      return;
    }
    n._story.resume();
  }
}

class ForkVersion extends Interrupt {
  @override
  void run(Narrator n) {}
}
