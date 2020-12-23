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
  // Actually might make more sense for separate UI listener not coupled to a
  // story, as a narrator is not coupled to a story. But it is nice to send
  // errors in the stream the UI already gets, and in that case we have to do
  // this lifecycle handling. Unless we make it a broadcast stream...
  StreamController<Event> _narratorEvents;

  Narrator(this._script, this._archive, this._stopwatch, this._random,
      this._clearPalette, this._ui) {
    _ui.interrupts.listen((event) {
      event.run(this);
    });
  }

  Future start() async {
    await stop();

    var palette = _clearPalette();
    var version = Version('unnamed');

    _playToUi(palette);
    _story = Story(
        '1', _script, palette, _stopwatch, _ui.actions, () => Duration.zero);
    _record(palette, version);
  }

  Future continueFrom(String versionName) async {
    await stop();

    var version = _archive[versionName];

    if (version == null) {
      throw ArgumentError.value(
          versionName, 'versionName', 'not found in archive');
    }

    var palette = _clearPalette();
    var replayedActions = StreamController<Action>();
    var actions = Rx.concat([replayedActions.stream, _ui.actions]);

    _playToUi(palette);

    _story = Story('1', _script, palette, _stopwatch, actions, () {
      // TODO: could publish a "loading" event somewhere so UI can react to all
      //  the rapid-fire events accordingly
      var record = version.actions;
      var lastOffset = Duration.zero;

      for (var recorded in record) {
        Future.delayed(lastOffset = recorded.offset, () {
          var action =
              palette.serializers.deserialize(recorded.action) as Action;
          replayedActions.add(action);
        });
      }

      Future.delayed(lastOffset, () => replayedActions.close());

      return lastOffset;
    });

    _record(palette, version);
  }

  Future stop() async {
    if (_story == null) {
      return Future.sync(() {});
    }

    await _story.close();
    await _narratorEvents?.close();
    await _ui.stopped;
  }

  List<String> saves() {}

  void _playToUi(Palette palette) {
    _narratorEvents = StreamController<Event>();
    _ui.play(Rx.merge([_narratorEvents.stream, palette.events]));
  }

  void _record(Palette palette, Version version) {
    _story.offsetActions.listen((action) {
      var serialized = palette.serializers.serialize(action.action);
      version.record(action.offset, serialized);
      _archive.save(version);
    });
  }
}

class Story {
  final String storyId;
  final PausableZone _pausableZone;
  final Palette _palette;
  final Stopwatch _stopwatch;
  final _offsetActions = StreamController<OffsetAction>();

  StreamSubscription _actionsSubscription;

  Story(this.storyId, Script script, this._palette, this._stopwatch,
      Stream<Action> actions, Duration Function() load)
      : _pausableZone = PausableZone(() => _stopwatch.elapsed) {
    _start(script, load, actions);
  }

  void _start(Script script, Duration Function() load, Stream<Action> actions) {
    var fastForwarder = FastForwarder(() => _pausableZone.offset);

    // TODO: move this?
    _palette.events.listen(
        (event) => print('event: ${fastForwarder.currentOffset} $event'));

    _pausableZone.run((c) {
      fastForwarder.runFastForwardable((ff) {
        _actionsSubscription = actions.listen((action) {
          var offset = fastForwarder.currentOffset;

          if (_pausableZone.isPaused) {
            // TODO: emit error somehow?
            print('caught action while paused, ignoring: $offset $action');
            return;
          }

          print('action: $offset $action');
          action.perform(_palette[action.inkType]);

          // TODO: should this check be here?
          if (!ff.isFastForwarding) {
            _offsetActions.add(OffsetAction(offset, action));
          }
        });

        _stopwatch.start();
        script(_palette);
        var lastOffset = load();

        ff.fastForward(lastOffset);
      });
    });
  }

  Stream<OffsetAction> get offsetActions => _offsetActions.stream;

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
  void run(Narrator n);
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
      n._narratorEvents.addError(
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
      n._narratorEvents.addError(
          StateError("can't resume story; no story is currently being told."));
      return;
    }
    n._story.resume();
  }
}

class SaveVersion extends Interrupt {
  @override
  void run(Narrator n) {
    // n.save(id);
  }
}

class ForkVersion extends Interrupt {
  @override
  void run(Narrator n) {}
}

class OffsetAction {
  final Duration offset;
  final Action action;

  OffsetAction(this.offset, this.action);
}
