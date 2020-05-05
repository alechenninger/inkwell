import 'dart:async';
import 'dart:collection';

export 'dart:async' show Zone;

// TODO: Consider a "StoryZone" which aggregates all capabilities for stories
//   another one that would be useful might be scaling times e.g 1 second is actually 2
abstract class PausableZone {
  factory PausableZone(Duration Function() parentOffset, {Zone parent}) =
  _CallbackQueueZone;

  void pause();
  void resume();
  bool get isPaused;
  Duration get offset;
  Duration get parentOffset;
  R run<R>(R Function(Controller) f);
}

class Controller {
  final PausableZone _zone;

  Controller(this._zone);

  void pause() {
    _zone.pause();
  }

  void resume() {
    _zone.resume();
  }

  Duration get parentOffset => _zone.parentOffset;

  Duration get offset => _zone.offset;
}

/// A [PausableZone] which works by precisely resuming timers in order, which
/// requires special handling for periodics.
class _OrderedTimerZone implements PausableZone {
  /// Timers which are currently running, so we can track what we need to pause.
  ///
  /// Timers are ordered by [_sequence], so we pause and resume cycles retain
  /// originally scheduled order.
  final _running = SplayTreeSet<_Scheduled>();

  /// Timers which are currently paused, so we can track what we need to resume.
  ///
  /// Timers are ordered by [_sequence], so we pause and resume cycles retain
  /// originally scheduled order.
  final _paused = SplayTreeSet<_Scheduled>();

  /// The offset of the parent zone, which progresses independently of pauses.
  ///
  /// In most cases this is the "real", monotonic time a player experiences.
  Duration get parentOffset => _parentOffset();

  final Duration Function() _parentOffset;

  /// The offset of this zone, which does not progress while paused.
  Duration get offset => _pausedAt ?? parentOffset - _pausedFor;

  /// The parent offset that we last paused at
  Duration _pausedAt;

  bool get isPaused => _pausedAt != null;

  /// The cumulative total time the zone has been paused
  Duration _pausedFor = Duration.zero;

  /// Maintains a sequence number to order timers in creation order
  int _sequence = 0;

  int _nextSequence() {
    return _sequence++;
  }

  /// Forked zone with pausable timers
  Zone _zone;

  _OrderedTimerZone(this._parentOffset, {Zone parent}) {
    parent = parent ?? Zone.current;
    _zone = parent.fork(
        specification: ZoneSpecification(
          createPeriodicTimer: _pausablePeriodicTimer,
          createTimer: _pausableTimer,
          scheduleMicrotask: _pausableMicrotask,
        ));
  }

  R run<R>(R Function(Controller) action) {
    return _zone.run(() {
      return action(Controller(this));
    });
  }

  void pause() {
    if (_pausedAt != null) return;
    _pausedAt = _parentOffset();

    for (var scheduled in _running.toList(growable: false)) {
      var timer = scheduled.timer;
      timer.pause();
    }
    // TODO: also microtasks?
  }

  void resume() {
    _pausedFor += _parentOffset() - _pausedAt;
    _pausedAt = null;

    // TODO: microtasks?
    _resumeUntilNextPeriodic();
  }

  void _resumeUntilNextPeriodic({Duration nextPeriodic}) {
    if (_paused.isEmpty) return;

    for (var scheduled in _paused.toList(growable: false)) {
      if (nextPeriodic != null && scheduled.nextCall >= nextPeriodic) {
        continue;
      }

      var timer = scheduled.timer;

      if (timer is _PausableNonPeriodicTimer) {
        timer.startFrom(offset);
      } else {
        var periodic = timer as _PausablePeriodicTimer;

        var unpause = continueResumeWithPeriodicAt(scheduled, periodic,
            nextPeriodic: nextPeriodic);
        unpause.startFrom(offset);
      }

      if (scheduled.forPeriodic) {
        nextPeriodic = scheduled.nextCall;
      }
    }
  }

  /// Creates a timer which unpauses [periodic] so it starts up at the
  /// [scheduled] time and sequence. Upon running, remaining timers will be
  /// unpaused, which ensures the original order is maintained.
  ///
  /// Once started, no other timers should be resumed unless they occur before
  /// [scheduled].
  _PausableNonPeriodicTimer continueResumeWithPeriodicAt(
      _Scheduled scheduled, _PausablePeriodicTimer periodic,
      {Duration nextPeriodic}) {
    _paused.remove(scheduled);

    var timer = _PausableNonPeriodicTimer.forPeriodic(
        this,
        scheduled.sequence,
            (t, d) => _zone.parent.createTimer(d, () {
          _running.remove(t._scheduled);

          if (periodic.isActive) {
            periodic.start(runNow: true, until: nextPeriodic);
          }

          _resumeUntilNextPeriodic(nextPeriodic: nextPeriodic);
        }),
        scheduled.nextCall);

    return timer;
  }

  Timer _pausableTimer(Zone self, ZoneDelegate parent, Zone zone,
      Duration duration, void Function() f) {
    var answer = _PausableNonPeriodicTimer(
        this,
        _nextSequence(),
            (t, d) => parent.createTimer(self, d, () {
          _running.remove(t._scheduled);
          f();
        }),
        offset + duration);

    if (!isPaused && _paused.length == 1) {
      answer.startFrom(offset);
    }

    return answer;
  }

  Timer _pausablePeriodicTimer(Zone self, ZoneDelegate parent, Zone zone,
      Duration duration, void Function(Timer) f) {
    var answer = _PausablePeriodicTimer(
        this,
        _nextSequence(),
            (f) => parent.createPeriodicTimer(self, duration, (_) => f()),
        duration,
        f);

    if (!isPaused && _paused.length == 1) {
      answer.start();
    }

    return answer;
  }

  void _pausableMicrotask(
      Zone self, ZoneDelegate parent, Zone zone, void Function() f) {
    parent.scheduleMicrotask(zone, f);
  }

  @override
  String toString() {
    return 'PausableZone{}';
  }
}

class _Scheduled implements Comparable<_Scheduled> {
  final Duration nextCall;
  final int sequence;
  final _PausableTimer timer;
  final bool forPeriodic;

  _Scheduled(this.nextCall, this.sequence, this.timer, this.forPeriodic);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is _Scheduled &&
              runtimeType == other.runtimeType &&
              nextCall == other.nextCall &&
              sequence == other.sequence &&
              timer == other.timer;

  @override
  int get hashCode => nextCall.hashCode ^ sequence.hashCode ^ timer.hashCode;

  @override
  int compareTo(_Scheduled other) {
    return sequence.compareTo(other.sequence);
  }

  @override
  String toString() {
    return '_Scheduled{nextCall: $nextCall, sequence: $sequence, timer: $timer}';
  }
}

abstract class _PausableTimer implements Timer {
  void pause();
}

class _PausableNonPeriodicTimer implements _PausableTimer {
  final _OrderedTimerZone _zone;
  final Timer Function(_PausableNonPeriodicTimer, Duration) _createTimer;
  _Scheduled _scheduled;
  Timer _delegate;
  bool _cancelled = false;

  _PausableNonPeriodicTimer(
      this._zone, int sequence, this._createTimer, Duration nextCall) {
    _scheduled = _Scheduled(nextCall, sequence, this, false);
    pause();
  }

  _PausableNonPeriodicTimer.forPeriodic(
      this._zone, int sequence, this._createTimer, Duration nextCall) {
    _scheduled = _Scheduled(nextCall, sequence, this, true);
    pause();
  }

  void pause() {
    _delegate?.cancel();
    _zone._running.remove(_scheduled);
    _zone._paused.add(_scheduled);
  }

  void startFrom(Duration offset) {
    if (!isActive) {
      throw StateError('Timer is not active anymore');
    }

    if (_scheduled.nextCall < offset) {
      throw StateError('Cannot start timer at $offset; timer already should '
          'have run at ${_scheduled.nextCall}');
    }
    _zone._running.add(_scheduled);
    _zone._paused.remove(_scheduled);
    _delegate = _createTimer(this, _scheduled.nextCall - offset);
  }

  @override
  void cancel() {
    _delegate?.cancel();
    _zone._running.remove(_scheduled);
    _cancelled = true;
  }

  @override
  bool get isActive =>
      !_cancelled &&
          // TODO: consider tracking done in this class... it would make this easier
          //   and it is onen of the few places we still have add/remove logic in
          //   the zone
          (_zone._running.contains(_scheduled) ||
              _zone._paused.contains(_scheduled));

  @override
  int get tick => _delegate?.tick ?? 0;
}

class _PausablePeriodicTimer implements _PausableTimer {
  final _OrderedTimerZone _zone;
  final Timer Function(void Function() f) _createTimer;
  final int _sequence;
  final Duration _period;
  final Function(Timer) _callback;
  _Scheduled _next;
  Timer _delegate;
  bool _cancelled = false;
  //int _offsetTicks;

  _PausablePeriodicTimer(this._zone, this._sequence, this._createTimer,
      this._period, this._callback) {
    pause();
  }

  void pause() {
    _delegate?.cancel();

    if (_next != null) {
      _zone._running.remove(_next);
      _zone._paused.add(_next);
    } else {
      _next = _Scheduled(_zone.offset + _period, _sequence, this, true);
      _zone._paused.add(_next);
    }
    // Not really sure this is right...
    //_offsetTicks = _offsetTicks + _delegate?.tick;
  }

  void start({bool runNow = false, Duration until}) {
    if (!isActive) {
      throw StateError('Timer is not active anymore');
    }

    if (runNow) {
      _callback(this);
    }

    if (_next != null) {
      _zone._paused.remove(_next);
    }

    _next = _Scheduled(_zone.offset + _period, _sequence, this, true);

    if (until != null && _next.nextCall >= until) {
      pause();
    } else {
      _zone._running.add(_next);
      _delegate = _createTimer(() {
        _zone._running.remove(_next);
        _next = _Scheduled(_next.nextCall + _period, _sequence, this, true);

        if (until != null && _next.nextCall >= until) {
          pause();
        } else {
          _zone._running.add(_next);
        }

        _callback(this);
      });
    }
  }

  bool get isStarted => _delegate != null;

  @override
  void cancel() {
    _delegate?.cancel();
    if (_next != null) {
      _zone._running.remove(_next);
      _zone._paused.remove(_next);
    }
    _cancelled = true;
  }

  @override
  bool get isActive => !_cancelled;

  @override
  //offsetTicks + _delegate?.tick ?? 0;
  int get tick => throw UnimplementedError('tick');
}

/// A [PausableZone] which works by decoupling timers from their callbacks.
/// Every timer runs the next callback in the queue, regardless of what callback
/// the timer is actually associated with. Every callback tracks a timer that
/// is associated only in timing, not actually what callback the timer will run.
///
/// To pause, we simply cancel all timers.
///
/// To resume, we reschedule timers for each callback: one that will run at each
/// callback's time. Each timer will then pop the next callback off the queue.
///
/// This makes it easy to schedule timers, because the order of scheduled timers
/// does not matter as long as they are scheduled at the right times. Callbacks
/// are always called in the right order, because timers only ever run the next
/// callback that should be run.
class _CallbackQueueZone implements PausableZone {
  final _callbacks = SplayTreeSet<_ScheduledCallback>();

  /// The offset of the parent zone, which progresses independently of pauses.
  ///
  /// In most cases this is the "real", monotonic time a player experiences.
  Duration get parentOffset => _parentOffset();

  final Duration Function() _parentOffset;

  /// The offset of this zone, which does not progress while paused.
  Duration get offset => _pausedAt ?? parentOffset - _pausedFor;

  /// The parent offset that we last paused at
  Duration _pausedAt;

  bool get isPaused => _pausedAt != null;

  /// The cumulative total time the zone has been paused
  Duration _pausedFor = Duration.zero;

  /// Maintains a sequence number to order timers in creation order
  int _sequence = 0;

  int _nextSequence() {
    return _sequence++;
  }

  /// Forked zone with pausable timers
  Zone _zone;

  _CallbackQueueZone(this._parentOffset, {Zone parent}) {
    parent = parent ?? Zone.current;
    _zone = parent.fork(
        specification: ZoneSpecification(
          createPeriodicTimer: _pausablePeriodicTimer,
          createTimer: _pausableTimer,
          scheduleMicrotask: _pausableMicrotask,
        ));
  }

  void pause() {
    if (_pausedAt != null) return;
    _pausedAt = _parentOffset();

    for (var cb in _callbacks) {
      cb._timer?.cancel();
    }
  }

  void resume() {
    _pausedFor += parentOffset - _pausedAt;
    _pausedAt = null;

    for (var cb in _callbacks) {
      var remaining = cb.nextCall - offset;
      Timer timer;

      // Schedule timer(s) at the timing(s) for this callback.

      if (cb.isPeriodic) {
        timer = _zone.parent.createTimer(remaining, () {
          var periodic = _zone.parent
              .createPeriodicTimer(cb.duration, (_) => _runNextCallback());
          cb._timer = periodic;

          _runNextCallback();
        });
      } else {
        timer = _zone.parent.createTimer(remaining, _runNextCallback);
      }

      cb._timer = timer;
    }
  }

  R run<R>(R Function(Controller) f) {
    return _zone.run(() {
      return f(Controller(this));
    });
  }

  void _cancel(int id) {
    // TODO: could index callbacks by id
    var cb = _callbacks.firstWhere((cb) => cb.sequence == id);
    cb._timer?.cancel();
    _callbacks.remove(cb);
  }

  bool _isActive(int id) => _callbacks.any((cb) => cb.sequence == id);

  int _ticks(int id) {
    throw UnimplementedError();
  }

  _ScheduledCallback _popCallback() {
    var first = _callbacks.first;
    _callbacks.remove(first);
    return first;
  }

  void _runNextCallback() {
    var next = _popCallback();

    if (next.isPeriodic) {
      next.callback(_CallbackTimer(next.sequence, this));
      if (_isActive(next.sequence)) {
        _callbacks.add(next.next());
      }
    } else {
      next.callback();
    }
  }

  Timer _pausableTimer(Zone self, ZoneDelegate parent, Zone zone,
      Duration duration, void Function() f) {
    var scheduled = _ScheduledCallback(
        _nextSequence(), duration, offset, ([t]) => f(), false, this);
    _callbacks.add(scheduled);

    if (!isPaused) {
      var timer = parent.createTimer(self, duration, _runNextCallback);
      scheduled._timer = timer;
    }

    return _CallbackTimer(scheduled.sequence, this);
  }

  Timer _pausablePeriodicTimer(Zone self, ZoneDelegate parent, Zone zone,
      Duration duration, void Function(Timer) f) {
    var scheduled = _ScheduledCallback(
        _nextSequence(), duration, offset, ([t]) => f(t), true, this);
    _callbacks.add(scheduled);

    if (!isPaused) {
      var timer =
      parent.createPeriodicTimer(self, duration, (_) => _runNextCallback());
      scheduled._timer = timer;
    }

    return _CallbackTimer(scheduled.sequence, this);
  }

  void _pausableMicrotask(
      Zone self, ZoneDelegate parent, Zone zone, void Function() f) {
    parent.scheduleMicrotask(zone, f);
  }
}

class _ScheduledCallback implements Comparable<_ScheduledCallback> {
  final int sequence;
  final Duration duration;
  final Duration started;
  final void Function([Timer]) callback;
  final bool isPeriodic;

  final _CallbackQueueZone _zone;

  /// A timer that will run at the same offset this callback is (next)
  /// scheduled.
  Timer _timer;

  _ScheduledCallback(this.sequence, this.duration, this.started, this.callback,
      this.isPeriodic, this._zone);

  _ScheduledCallback.next(this.sequence, this.duration, this.started,
      this.callback, this.isPeriodic, this._zone, this._timer);

  Duration get nextCall => started + duration;

  _ScheduledCallback next() {
    return _ScheduledCallback.next(sequence, duration, started + duration,
        callback, isPeriodic, _zone, _timer);
  }

  @override
  int compareTo(_ScheduledCallback other) {
    var byCall = nextCall.compareTo(other.nextCall);
    if (byCall != 0) return byCall;
    return sequence.compareTo(other.sequence);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is _ScheduledCallback &&
              runtimeType == other.runtimeType &&
              sequence == other.sequence &&
              started == other.started;

  @override
  int get hashCode => sequence.hashCode ^ started.hashCode;

  @override
  String toString() {
    return '_ScheduledTimer{sequence: $sequence, duration: $duration, '
        'started: $started, callback: $callback, isPeriodic: $isPeriodic}';
  }
}

class _CallbackTimer implements Timer {
  final int _id;
  final _CallbackQueueZone _zone;

  _CallbackTimer(this._id, this._zone);

  @override
  void cancel() {
    _zone._cancel(_id);
  }

  @override
  bool get isActive => _zone._isActive(_id);

  @override
  int get tick => _zone._ticks(_id);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is _CallbackTimer &&
              runtimeType == other.runtimeType &&
              _id == other._id &&
              _zone == other._zone;

  @override
  int get hashCode => _id.hashCode ^ _zone.hashCode;

  @override
  String toString() {
    return '_CallbackTimer{_id: $_id, _zone: $_zone}';
  }
}
