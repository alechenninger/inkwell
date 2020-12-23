library august.narrator;

import 'dart:async';
import 'dart:math';

import 'package:rxdart/rxdart.dart';

import 'src/core.dart';
import 'src/pausable.dart';
import 'src/persistence.dart';
import 'ui.dart';

class Narrator {
  final Script _script;
  final Archive _archive;

  // TODO: need to be Stopwatch f() if we want to manage multiple stories
  final Stopwatch _stopwatch;
  final Random _random;
  final UserInterface _ui;
  final Palette Function() _clearPalette;

  // TODO: not sure if this is right
  final _notices = StreamController<Notice>();

  // TODO: Could have server support multiple?
  // Would this require separate isolates for each?
  // Or does it matter that microtasks and events would interleave?
  // I don't believe it should, technically, since each story itself would still
  // be ordered.
  // Would that be a separate narrator for each story anyway? Because multiple
  // users would imply multiple UIs?
  _Story _story;

  Narrator(this._script, this._archive, this._stopwatch, this._random,
      this._clearPalette, this._ui) {
    _ui.interrupts.listen((event) {
      event.run(this);
    });
    _ui.notice(_notices.stream);
  }

  Future start() async {
    await stop();

    var version = Version('unnamed');

    _story = _Story.start('1', this, version);
  }

  Future continueFrom(String versionName) async {
    await stop();

    var version = _archive[versionName];

    if (version == null) {
      throw ArgumentError.value(
          versionName, 'versionName', 'not found in archive');
    }

    _story = _Story.start('1', this, version);
  }

  Future stop() async {
    if (_story == null) {
      return Future.sync(() {});
    }

    await _story.close();
    await _ui.stopped;
  }

  List<String> saves() {
    // TODO: add versionNames to archive
    return _archive.versions.map((v) => v.name).toList(growable: false);
  }
}

class _Story {
  final String storyId;
  final Narrator _narrator;
  final Palette _palette;
  final Stopwatch _stopwatch;

  final _recordedActions = StreamController<OffsetAction>();

  PausableZone _pausableZone;
  SaveStrategy _saveStrategy = (s) => s.bufferCount(1);

  StreamSubscription _actionsSubscription;

  _Story.start(this.storyId, this._narrator, Version version)
      : _stopwatch = _narrator._stopwatch,
        _palette = _narrator._clearPalette() {
    _pausableZone = PausableZone(() => _stopwatch.elapsed);
    _start(version);
  }

  void _start(Version version) {
    var script = _narrator._script;
    var ui = _narrator._ui;
    var replayedActions = StreamController<Action>();
    var fastForwarder = FastForwarder(() => _pausableZone.offset);

    var events = _palette.events;
    var actions = Rx.concat([replayedActions.stream, ui.actions]);

    ui.play(events);

    // TODO: move this?
    _palette.events.listen(
        (event) => print('event: ${fastForwarder.currentOffset} $event'));

    _saveStrategy(_recordedActions.stream).listen((actions) {
      actions.forEach((action) => version.record(action.offset, action.action));
      _narrator._archive.save(version);
    });

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
            var serialized = _palette.serializers.serialize(action);
            _recordedActions.add(OffsetAction(offset, serialized));
          }
        });

        _stopwatch.start();
        script(_palette);

        // TODO: could publish a "loading" event somewhere so UI can react to all
        //  the rapid-fire events accordingly
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
    return Future.wait([
      _palette.close(),
      // _narratorEvents.close(),
      _actionsSubscription.cancel()
    ]);
  }
}

typedef SaveStrategy = Stream<List<OffsetAction>> Function(
    Stream<OffsetAction>);

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

class ContinueStory extends Interrupt {
  @override
  void run(Narrator n) {
    n.continueFrom(n.saves().first);
  }
}

class PauseStory extends Interrupt {
  @override
  void run(Narrator n) {
    if (n._story == null) {
      n._notices.add(
          Notice("can't pause story; no story is currently being told."));
      return;
    }
    n._story.pause();
  }
}

class ResumeStory extends Interrupt {
  @override
  void run(Narrator n) {
    if (n._story == null) {
      n._notices.add(
          Notice("can't resume story; no story is currently being told."));
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

// TODO: serializable
// TODO: subtypes?
class Notice {
  final String message;

  Notice(this.message);
}
