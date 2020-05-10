import 'package:quiver/time.dart';

import 'dart:async';
import 'dart:collection';

// TODO: maybe combine this lib with input.dart?

abstract class Persistence {
  // TODO maybe should be getSavedInteractions(String scriptName, int version)
  // Today persistence must be instantiated to know how to read persisted events
  // for a particular script
  List<SavedAction> get savedInteractions;
  void saveInteraction(Duration offset, String moduleName,
      String interactionName, Map<String, dynamic> parameters);
}

class NoPersistence implements Persistence {
  @override
  final savedInteractions = const [];

  @override
  void saveInteraction(Duration offset, String moduleName, String name,
      Map<String, dynamic> parameters) {}

  const NoPersistence();
}

class SavedAction {
  final Duration offset;
  final String moduleName;
  final String name;
  final Map<String, dynamic> parameters;

  SavedAction(this.moduleName, this.name, this.parameters, this.offset);

  SavedAction.fromJson(Map<String, Object> json)
      : moduleName = json['moduleName'] as String,
        name = json['name'] as String,
        parameters = json['parameters'] as Map<String, dynamic>,
        offset = Duration(milliseconds: json['offsetMillis'] as int);

  Map<String, Object> toJson() => {
        'moduleName': moduleName,
        'name': name,
        'parameters': parameters,
        'offsetMillis': offset.inMilliseconds
      };
}

// Adapted from quiver's FakeAsync
class FastForwarder {
  Zone _zone;
  Duration _elapsed = Duration.zero;
  Duration _elapsingTo;
  final Queue<Function> _microtasks = Queue();
  final Set<_FastForwarderTimer> _timers = <_FastForwarderTimer>{};
  bool _useParentZone = true;
  DateTime _switchedToParent;
  final Clock _realClock;

  FastForwarder(this._realClock) {
    _switchedToParent = _realClock.now();
  }

  // FIXME: non-monotonic offset
  Duration get currentOffset => _useParentZone
      ? _elapsed + _realClock.now().difference(_switchedToParent)
      : _elapsed;

  void runFastForwardable(Function(FastForwarder) callback) {
    _useParentZone = false;
    _zone ??= Zone.current.fork(specification: _zoneSpec);
    _zone.run(() => callback(this));
    switchToParentZone();
  }

  void fastForward(Duration offset) {
    if (_useParentZone) {
      throw StateError('Cannot fast forward if switched to parent zone.');
    }
    if (offset.inMicroseconds < 0) {
      throw ArgumentError('Cannot fast forward with negative duration');
    }
    if (_elapsingTo != null) {
      throw StateError(
          'Cannot fast forward until previous fast forward is complete.');
    }
    _elapsingTo = _elapsed + offset;
    _runTimersUntil(_elapsingTo);
    _elapseTo(_elapsingTo);
    _elapsingTo = null;
  }

  void switchToParentZone() {
    _useParentZone = true;
    _switchedToParent = _realClock.now();

    while (_microtasks.isNotEmpty) {
      _zone.parent.scheduleMicrotask(_microtasks.removeFirst() as Callback);
    }

    while (_timers.isNotEmpty) {
      var t = _timers.first;
      if (t.isPeriodic) {
        // TODO: I think this has side effect of reordering timers, because a
        //   non-periodic timer at same time will run before a periodic timer
        //   where it might not have otherwise
        _zone.parent.createTimer(t.nextCall - _elapsed, () {
          var trackingTimer = _TrackingTimer();
          t.callback(trackingTimer);
          if (trackingTimer.isActive) {
            _zone.parent
                .createPeriodicTimer(t.duration, t.callback as TimerCallback);
          }
        });
      } else {
        _zone.parent.createTimer(t.nextCall - _elapsed, t.callback as Callback);
      }
      _timers.remove(t);
    }
  }

  ZoneSpecification get _zoneSpec => ZoneSpecification(
      createTimer: (_, parent, zone, duration, callback) =>
          _createTimer(parent, zone, duration, callback, false),
      createPeriodicTimer: (_, parent, zone, duration, callback) =>
          _createTimer(parent, zone, duration, callback, true),
      scheduleMicrotask: (_, parent, zone, microtask) => _useParentZone
          // TODO: not sure if passing right zone to scheduleMicrotask here
          ? parent.scheduleMicrotask(zone, microtask)
          : _microtasks.add(microtask));

  void _runTimersUntil(Duration elapsingTo) {
    _FastForwarderTimer next;
    while ((next = _getNextTimer()) != null && next.nextCall <= elapsingTo) {
      _elapseTo(next.nextCall);
      _runTimer(next);
      _drainMicrotasks();
    }
  }

  void _elapseTo(Duration to) {
    if (to > _elapsed) {
      _elapsed = to;
    }
  }

  Timer _createTimer(ZoneDelegate parent, Zone zone, Duration duration,
      Function callback, bool isPeriodic) {
    if (_useParentZone) {
      return isPeriodic
          ? parent.createPeriodicTimer(
              zone, duration, callback as TimerCallback)
          : parent.createTimer(zone, duration, callback as Callback);
    }
    var timer = _FastForwarderTimer(duration, callback, isPeriodic, this);
    _timers.add(timer);
    return timer;
  }

  _FastForwarderTimer _getNextTimer() => _timers.isEmpty
      ? null
      : _timers.reduce((t1, t2) => t1.nextCall <= t2.nextCall ? t1 : t2);

  void _runTimer(_FastForwarderTimer timer) {
    assert(timer.isActive);
    if (timer.isPeriodic) {
      timer.callback(timer);
      timer.nextCall += timer.duration;
    } else {
      timer.callback();
      _timers.remove(timer);
    }
  }

  void _drainMicrotasks() {
    while (_microtasks.isNotEmpty) {
      _microtasks.removeFirst()();
    }
  }

  bool _hasTimer(timer) => _timers.contains(timer);

  bool _cancelTimer(timer) => _timers.remove(timer);
}

class _FastForwarderTimer implements Timer {
  final Duration duration;
  final Function callback;
  final bool isPeriodic;
  final FastForwarder ff;
  Duration nextCall;

  static const _minDuration = Duration.zero;

  _FastForwarderTimer(
      Duration duration, this.callback, this.isPeriodic, this.ff)
      : duration = duration < _minDuration ? _minDuration : duration {
    nextCall = ff._elapsed + duration;
  }

  bool get isActive => ff._hasTimer(this);

  cancel() => ff._cancelTimer(this);

  @override
  int get tick => throw UnimplementedError('tick');
//      isPeriodic
//      ? min(
//          0,
//          (ff._elapsed - nextCall - duration).inMilliseconds ~/
//              duration.inMilliseconds)
//      : (ff._elapsed >= nextCall ? 1 : 0);
}

class _TrackingTimer implements Timer {
  bool isActive = true;
  cancel() {
    isActive = false;
  }

  @override
  int get tick => throw UnimplementedError('tick');
}

typedef Callback = void Function();
typedef TimerCallback = void Function(Timer timer);
