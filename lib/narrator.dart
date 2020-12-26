library august.narrator;

import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'src/core.dart';
import 'src/pausable.dart';
import 'src/persistence.dart';

class Narrator {
  final Script _script;
  // TODO: archive might make sense as client-side / decoupled from narrator
  final Archive _archive;

  // TODO: need to be Stopwatch f() if we want to manage multiple stories
  final Stopwatch _stopwatch;
  final Palette Function() _clearPalette;

  // TODO: Could have server support multiple?
  // Would this require separate isolates for each?
  // Or does it matter that microtasks and events would interleave?
  // I don't believe it should, technically, since each story itself would still
  // be ordered.
  // Would that be a separate narrator for each story anyway? Because multiple
  // users would imply multiple UIs?
  Story _story;

  Narrator(this._script, this._archive, this._stopwatch, this._clearPalette);

  Future<Story> start() async {
    await stop();

    var version = Version('unnamed');

    return _story = Story._start(this, version);
  }

  Future<Story> continueFrom(String versionName) async {
    await stop();

    var version = _archive[versionName];

    if (version == null) {
      throw ArgumentError.value(
          versionName, 'versionName', 'not found in archive');
    }

    return _story = Story._start(this, version);
  }

  Future stop() async {
    if (_story == null) {
      return Future.sync(() {});
    }

    await _story.close();
  }

  List<String> saves() {
    // TODO: add versionNames to archive
    return _archive.versions.map((v) => v.name).toList(growable: false);
  }
}

class Story {
  final Narrator _narrator;
  final Palette _palette;
  final Stopwatch _stopwatch;

  final _events = StreamController<Event>(sync: true);
  final _userActions = StreamController<Action>();
  final _recordedActions = StreamController<OffsetAction>();

  PausableZone _pausableZone;
  // TODO: make configurable, persistable as user options/settings
  final SaveStrategy _saveStrategy = _saveEveryAction;

  StreamSubscription _actionsSubscription;

  Story._start(this._narrator, Version version)
      : _stopwatch = _narrator._stopwatch,
        _palette = _narrator._clearPalette() {
    _pausableZone = PausableZone(() => _stopwatch.elapsed);
    _doStart(version);
  }

  void _doStart(Version version) {
    var script = _narrator._script;
    var replayedActions = StreamController<Action>();
    var fastForwarder = FastForwarder(() => _pausableZone.offset);
    var actions = Rx.concat([replayedActions.stream, _userActions.stream]);

    _palette.events
        .doOnData(
            (event) => print('event: ${fastForwarder.currentOffset} $event'))
        .pipe(_events);

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
        var lastOffset = Duration.zero;

        for (var recorded in version.actions) {
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

  Stream<Event> get events => _events.stream;

  bool get isPaused => _pausableZone.isPaused;

  // Or add stream of actions?
  void attempt(Action action) {
    _userActions.add(action);
  }

  void pause() {
    _pausableZone.pause();
    print('paused');
  }

  void resume() {
    _pausableZone.resume();
    print('resumed');
  }

  Future close() async {
    _stopwatch.stop();
    _stopwatch.reset();
    await _palette.close();
    await _events.done;
    await _userActions.close();
    await _actionsSubscription.cancel();
  }
}

typedef SaveStrategy = Stream<List<OffsetAction>> Function(
    Stream<OffsetAction>);

final SaveStrategy _saveEveryAction = (s) => s.bufferCount(1);
