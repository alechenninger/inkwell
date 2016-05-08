part of august;

abstract class Persistence {
  List<SavedInteraction> get savedInteractions;
  void saveInteraction(Duration offset, String moduleName,
      String interactionName, Map<String, dynamic> parameters);
}

class NoPersistence implements Persistence {
  final savedInteractions = const [];
  void saveInteraction(Duration offset, String moduleName,
      String interactionName, Map<String, dynamic> parameters) {}

  const NoPersistence();
}

class SavedInteraction implements Interaction {
  final Duration offset;
  final String moduleName;
  final String name;
  final Map<String, dynamic> parameters;

  SavedInteraction(this.moduleName, this.name, this.parameters, this.offset);

  SavedInteraction.fromJson(Map json)
      : moduleName = json['moduleName'],
        name = json['name'],
        parameters = json['parameters'] as Map<String, dynamic>,
        offset = new Duration(milliseconds: json['offsetMillis']);

  Map toJson() => {
        'moduleName': moduleName,
        'name': name,
        'parameters': parameters,
        'offsetMillis': offset.inMilliseconds
      };
}

// Adapted from quiver's FakeAsync
class FastForwarder {
  Zone _zone;
  Duration _elapsed = Duration.ZERO;
  Duration _elapsingTo;
  Queue<Function> _microtasks = new Queue();
  Set<_FastForwarderTimer> _timers = new Set<_FastForwarderTimer>();
  bool _useParentZone = false;
  DateTime _switchedToParent;
  final Clock _realClock;

  FastForwarder(this._realClock);

  Duration getCurrentPlayTime() => _useParentZone
      ? _elapsed + _realClock.now().difference(_switchedToParent)
      : _elapsed;

  void fastForward(Duration offset) {
    if (_useParentZone) {
      throw new StateError("Cannot fast forward if switched to parent zone.");
    }
    if (offset.inMicroseconds < 0) {
      throw new ArgumentError('Cannot fast forward with negative duration');
    }
    if (_elapsingTo != null) {
      throw new StateError(
          'Cannot fast forward until previous fast forward is complete.');
    }
    _elapsingTo = _elapsed + offset;
    _runTimersUntil(_elapsingTo);
    _elapseTo(_elapsingTo);
    _elapsingTo = null;
  }

  run(callback(FastForwarder self)) {
    if (_zone == null) {
      _zone = Zone.current.fork(specification: _zoneSpec);
    }
    return _zone.run(() => callback(this));
  }

  ZoneSpecification get _zoneSpec => new ZoneSpecification(
      createTimer: (_, parent, zone, duration, callback) =>
          _createTimer(parent, zone, duration, callback, false),
      createPeriodicTimer: (_, parent, zone, duration, callback) =>
          _createTimer(parent, zone, duration, callback, true),
      scheduleMicrotask: (_, parent, zone, microtask) => _useParentZone
          // TODO: not sure if passing right zone to scheduleMicrotask here
          ? parent.scheduleMicrotask(zone, microtask)
          : _microtasks.add(microtask));

  _runTimersUntil(Duration elapsingTo) {
    var next;
    while ((next = _getNextTimer()) != null && next.nextCall <= elapsingTo) {
      _elapseTo(next.nextCall);
      _runTimer(next);
      _drainMicrotasks();
    }
  }

  _elapseTo(Duration to) {
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
    var timer = new _FastForwarderTimer(duration, callback, isPeriodic, this);
    _timers.add(timer);
    return timer;
  }

  _FastForwarderTimer _getNextTimer() => _timers.isEmpty
      ? null
      : _timers.reduce((t1, t2) => t1.nextCall <= t2.nextCall ? t1 : t2);

  _runTimer(_FastForwarderTimer timer) {
    assert(timer.isActive);
    if (timer.isPeriodic) {
      timer.callback(timer);
      timer.nextCall += timer.duration;
    } else {
      timer.callback();
      _timers.remove(timer);
    }
  }

  _drainMicrotasks() {
    while (_microtasks.isNotEmpty) {
      _microtasks.removeFirst()();
    }
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
        _zone.parent.createTimer(t.nextCall - _elapsed, () {
          var trackingTimer = new _TrackingTimer();
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

  _hasTimer(timer) => _timers.contains(timer);

  _cancelTimer(timer) => _timers.remove(timer);
}

class _FastForwarderTimer implements Timer {
  final Duration duration;
  final Function callback;
  final bool isPeriodic;
  final FastForwarder ff;
  Duration nextCall;

  static const _minDuration = Duration.ZERO;

  _FastForwarderTimer(
      Duration duration, this.callback, this.isPeriodic, this.ff)
      : duration = duration < _minDuration ? _minDuration : duration {
    nextCall = ff._elapsed + duration;
  }

  bool get isActive => ff._hasTimer(this);

  cancel() => ff._cancelTimer(this);
}

class _TrackingTimer implements Timer {
  bool isActive = true;
  cancel() {
    isActive = false;
  }
}

typedef void Callback();
typedef void TimerCallback(Timer timer);
