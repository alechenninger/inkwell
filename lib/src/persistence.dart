part of august;

abstract class Persistence {
  List<InterfaceEvent> get savedEvents;
  void saveEvent(InterfaceEvent event);
}

class NoopPersistance implements Persistence {
  final List savedEvents = const [];
  void saveEvent(_) {}

  const NoopPersistance();
}

class InterfaceEvent {
  final Duration offset;
  final String moduleName;
  final String action;
  final Map<String, dynamic> args;

  InterfaceEvent(Type moduleType, this.action, this.args, this.offset)
      : this.moduleName = '$moduleType';

  InterfaceEvent.fromJson(Map json)
      : moduleName = json['moduleName'],
        action = json['action'],
        args = json['args'],
        offset = new Duration(milliseconds: json['offsetMillis']);

  Map toJson() => {
        'moduleName': moduleName,
        'action': action,
        'args': args,
        'offsetMillis': offset.inMilliseconds
      };
}

// Adapted from quiver's FakeAsync
class _FastForwarder {
  Zone _zone;
  Duration _elapsed = Duration.ZERO;
  Duration _elapsingTo;
  Queue<Function> _microtasks = new Queue();
  Set<_FastForwarderTimer> _timers = new Set<_FastForwarderTimer>();
  bool _useParentZone = false;
  DateTime _switchedToParent;
  final Clock _realClock;

  _FastForwarder(this._realClock);

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

  run(callback(_FastForwarder self)) {
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
          ? parent.scheduleMicrotask(microtask)
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
          ? parent.createPeriodicTimer(zone, duration, callback)
          : parent.createTimer(zone, duration, callback);
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
      _zone.parent.scheduleMicrotask(_microtasks.removeFirst());
    }

    while (_timers.isNotEmpty) {
      var t = _timers.first;
      if (t.isPeriodic) {
        _zone.parent.createTimer(t.nextCall - _elapsed, () {
          var trackingTimer = new _TrackingTimer();
          t.callback(trackingTimer);
          if (trackingTimer.isActive) {
            _zone.parent.createPeriodicTimer(t.duration, t.callback);
          }
        });
      } else {
        _zone.parent.createTimer(t.nextCall - _elapsed, t.callback);
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
  final _FastForwarder ff;
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
  cancel() => isActive = false;
}
