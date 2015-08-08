part of august.core;

abstract class Persistence {
  List<InterfaceEvent> get savedEvents;
  void saveEvent(InterfaceEvent event);
}

class InterfaceEvent {
  final Duration offset;
  final String moduleName;
  final String action;
  final Map<String, dynamic> args;

  InterfaceEvent(this.moduleName, this.action, this.args, this.offset);

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

void fastForward(
    void run(CurrentPlayTime cpt), Clock realClock, Duration offset) {
  new _FastForwarder(realClock).run((ff) {
    run(() => ff.currentPlayTime());
    return ff.fastForward(offset);
  });
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

  Duration currentPlayTime() => _useParentZone
      ? _elapsed + _realClock.now().difference(_switchedToParent)
      : _elapsed;

  void fastForward(Duration offset) {
    if (_useParentZone) {
      throw new StateError("Can only fast forward once.");
    }
    if (offset.inMicroseconds < 0) {
      throw new ArgumentError('Cannot fast forward with negative duration');
    }
    if (_elapsingTo != null) {
      throw new StateError(
          'Cannot fast forward until previous fast forward is complete.');
    }
    _elapsingTo = _elapsed + offset;
    _drainTimersWhile(
        (_FastForwarderTimer next) => next.nextCall <= _elapsingTo);
  }

  run(callback(_FastForwarder self)) {
    if (_zone == null) {
      _zone = Zone.current.fork(specification: _zoneSpec);
    }
    return _zone.run(() => callback(this));
  }

  ZoneSpecification get _zoneSpec => new ZoneSpecification(
          createTimer: (_, parent, zone, Duration duration, Function callback) {
        return _createTimer(parent, zone, duration, callback, false);
      }, createPeriodicTimer:
              (_, parent, zone, Duration duration, Function callback) {
        return _createTimer(parent, zone, duration, callback, true);
      }, scheduleMicrotask: (_, parent, zone, Function microtask) {
        if (_useParentZone) {
          parent.scheduleMicrotask(microtask);
        } else {
          _microtasks.add(microtask);
        }
      });

  _drainTimersWhile(bool predicate(timer)) {
    _drainMicrotasks();
    var next = _getNextTimer();
    if (next != null && predicate(next)) {
      var nextCall = next.nextCall;
      var nextSet = new Set.from(_timers.where((t) => t.nextCall == nextCall));
      _elapseTo(nextCall);
      nextSet.forEach(_scheduleTimer);
      _zone.parent
          .createTimer(Duration.ZERO, () => _drainTimersWhile(predicate));
    } else {
      _elapseTo(_elapsingTo);
      _elapsingTo = null;
      _switchToParentZone();
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

  _FastForwarderTimer _getNextTimer() {
    return min(_timers,
        (timer1, timer2) => timer1.nextCall.compareTo(timer2.nextCall));
  }

  _scheduleTimer(_FastForwarderTimer timer) {
    assert(timer.isActive);
    if (timer.isPeriodic) {
      // Schedule the callback on the next event loop
      _zone.parent.createTimer(Duration.ZERO, () => timer.callback(timer));
      timer.nextCall += timer.duration;
    } else {
      // Schedule the callback on the next event loop
      _zone.parent.createTimer(Duration.ZERO, timer.callback);
      _timers.remove(timer);
    }
  }

  _drainMicrotasks() {
    while (_microtasks.isNotEmpty) {
      _microtasks.removeFirst()();
    }
  }

  void _switchToParentZone() {
    _useParentZone = true;
    _switchedToParent = _realClock.now();

    _microtasks.forEach(_zone.parent.scheduleMicrotask);
    _microtasks.clear();

    _timers.forEach((t) {
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
    });
    _timers.clear();
  }

  _hasTimer(timer) => _timers.contains(timer);

  _cancelTimer(timer) => _timers.remove(timer);
}

class _FastForwarderTimer implements Timer {
  final Duration duration;
  final Function callback;
  final bool isPeriodic;
  final _FastForwarder time;
  Duration nextCall;

  // TODO: In browser JavaScript, timers can only run every 4 milliseconds once
  // sufficiently nested:
  //     http://www.w3.org/TR/html5/webappapis.html#timer-nesting-level
  // Without some sort of delay this can lead to infinitely looping timers.
  // What do the dart VM and dart2js timers do here?
  static const _minDuration = Duration.ZERO;

  _FastForwarderTimer(
      Duration duration, this.callback, this.isPeriodic, this.time)
      : duration = duration < _minDuration ? _minDuration : duration {
    nextCall = time._elapsed + duration;
  }

  bool get isActive => time._hasTimer(this);

  cancel() => time._cancelTimer(this);
}

class _TrackingTimer implements Timer {
  bool isActive = true;
  cancel() => isActive = false;
}
