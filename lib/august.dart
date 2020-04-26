// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august;

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:quiver/check.dart';
import 'package:quiver/time.dart';
import 'package:rxdart/rxdart.dart';

export 'dart:async';
export 'package:quiver/time.dart' show Clock;

export 'src/story.dart';

// TODO: This library organization is a mess
part 'input.dart';
part 'ui.dart';
part 'src/events.dart';
part 'src/persistence.dart';
part 'src/scope.dart';
part 'src/observable.dart';

// Experimenting with a Module type to capture module design pattern
abstract class Module<UiType> {
  UiType ui(Sink<Interaction> interactionSink);
  Interactor interactor();
}

///
class PausableZone {
  /// All timers, regardless of state, so we can track what we need to pause.
  final _timers = PriorityQueue<_Scheduled>();

  /// Timers which are currently paused, so we can track what we need to resume.
  final _paused = PriorityQueue<_Scheduled>();

  final Duration Function() parentOffset;

  Duration _pausedAt;

  /// Orders timers
  int _sequence = 0;

  /// Forked zone with pausable timers
  Zone _zone;

  PausableZone(this.parentOffset) {
    _zone = Zone.current.fork(
        specification: ZoneSpecification(
      createPeriodicTimer: pausablePeriodicTimer,
      createTimer: pausableTimer,
      scheduleMicrotask: pausableMicrotask,
    ));
  }

  Timer pausablePeriodicTimer(Zone self, ZoneDelegate parent, Zone zone,
      Duration duration, void Function(Timer) f) {
    Timer _createTimer(void Function() f) {
      return parent.createPeriodicTimer(self, duration, (_) {
        f();
      });
    }

    var answer = _PausablePeriodicTimer(
        this, _nextSequence(), _createTimer, duration, f);

    _timers.add(answer._next);

    if (_isPaused) {
      _paused.add(answer._next);
    } else {
      answer.start();
    }

    return answer;
  }

  Timer pausableTimer(Zone self, ZoneDelegate parent, Zone zone,
      Duration duration, void Function() f) {
    Timer _createTimer(_PausableTimer t, Duration d) {
      var removeTimerThenRunCallback = () {
        _timers.remove(t._scheduled);
        f();
      };
      return parent.createTimer(self, d, removeTimerThenRunCallback);
    }

    var answer = _PausableTimer(this, _nextSequence(), _createTimer, duration);

    _timers.add(answer._scheduled);

    if (_isPaused) {
      _paused.add(answer._scheduled);
    } else {
      answer.start();
    }

    return answer;
  }

  int _nextSequence() {
    return _sequence++;
  }

  bool get _isPaused => _pausedAt != null;

  void pausableMicrotask(
      Zone self, ZoneDelegate parent, Zone zone, void Function() f) {
    parent.scheduleMicrotask(zone, f);
  }

  void pause() {
    // TODO: can stop the stopwatch if we don't need to keep track of how long
    //   we paused

    if (_pausedAt != null) return;
    _pausedAt = parentOffset();

    while (_timers.isNotEmpty) {
      var scheduled = _timers.removeFirst();
      var timer = scheduled.timer;
      // TODO: this can/should? polymorphic
      if (timer is _PausableTimer) {
        timer.pauseAt(_pausedAt);
      } else {
        (timer as _PausablePeriodicTimer).pause();
      }
      _paused.add(scheduled);
    }
    // TODO: also microtasks
  }

  void resume() {

    /*
    schedule all microtasks
    */

    _resumeAvailableTimers();

    /*
    restart all timers with durations - elapsed pause duration

    drain timers in order (order by next call, scheduled order)
    if not periodic, schedule
    if periodic, stop draining, schedule timer at offset which will then schedule periodic
    and start draining again per above algorithm


     */

    _pausedAt = null;
  }

  void _resumeAvailableTimers() {
    while (_paused.isNotEmpty) {
      var scheduled = _paused.removeFirst();
      var timer = scheduled.timer;

      if (timer is _PausableTimer) {
        timer.start();
      } else {
        var periodic = timer as _PausablePeriodicTimer;

        // TODO: come back to this
        // basically if the remaining time on the first tick is == period, we
        // can just directly start again. but how to tell?
//        if (!periodic.isStarted) {
//          periodic.start();
//          continue;
//        }

        // TODO: DRY this bit
        Timer _createTimer(_PausableTimer t, Duration d) {
          var continueResume = () {
            _timers.remove(t._scheduled);
            periodic.startNow();
            _resumeAvailableTimers();
          };
          return _zone.parent.createTimer(d, continueResume);
        }

        var answer = _PausableTimer(
            this, _nextSequence(), _createTimer, scheduled.nextCall - _pausedAt);
        answer.start();

        _timers.add(answer._scheduled);

        break;
      }
    }
  }

  R run<R>(R Function(Controller) action) {
    return _zone.run(() {
      return action(Controller(this));
    });
  }

  @override
  String toString() {
    return 'PausableZone{}';
  }
}

class Controller {
  final PausableZone _pausable;

  Controller(this._pausable);

  void pause() {
    _pausable.pause();
  }

  void resume() {
    _pausable.resume();
  }
}

class _Scheduled implements Comparable<_Scheduled> {
  final Duration nextCall;
  final int sequence;
  final Timer timer;

  _Scheduled(this.nextCall, this.sequence, this.timer);

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
    var byCall = nextCall.compareTo(other.nextCall);
    if (byCall != 0) return byCall;
    return sequence.compareTo(other.sequence);
  }
}

class _PausableTimer implements Timer {
  final PausableZone _zone;
  final Timer Function(_PausableTimer, Duration) _createTimer;
  _Scheduled _scheduled;
  Timer _delegate;
  Duration _timeRemaining;

  _PausableTimer(
      this._zone, int sequence, this._createTimer, Duration duration) {
    _scheduled = _Scheduled(_zone.parentOffset() + duration, sequence, this);
    _timeRemaining = duration;
  }

  void pauseAt(Duration offset) {
    _timeRemaining = _scheduled.nextCall - offset;
    _delegate.cancel();
  }

  void start() {
    _delegate = _createTimer(this, _timeRemaining);
  }

  @override
  void cancel() {
    _delegate.cancel();
    _zone._timers.remove(_scheduled);
  }

  @override
  bool get isActive => _delegate.isActive;

  @override
  int get tick => _delegate.tick;
}

class _PausablePeriodicTimer implements Timer {
  final PausableZone _zone;
  final Timer Function(void Function() f) _createTimer;
  final int _sequence;
  final Duration _period;
  final Function(Timer) _callback;
  _Scheduled _next;
  Timer _delegate;
  int _offsetTicks;

  _PausablePeriodicTimer(this._zone, this._sequence, this._createTimer,
      this._period, this._callback) {
    _next = _Scheduled(_zone.parentOffset() + _period, _sequence, this);
  }

  void pause() {
    _delegate?.cancel();
    // Not really sure this is right...
    //_offsetTicks = _offsetTicks + _delegate?.tick;
  }

  void startNow() {
    _zone._timers.remove(_next);
    _zone._timers
        .add(_next = _Scheduled(_next.nextCall + _period, _sequence, this));
    _callback(this);

    start();
  }

  void start() {
    _delegate = _createTimer(() {
      _zone._timers.remove(_next);
      _zone._timers
          .add(_next = _Scheduled(_next.nextCall + _period, _sequence, this));
      _callback(this);
    });
  }

  bool get isStarted => _delegate != null;

  @override
  void cancel() {
    _delegate?.cancel();
    _zone._timers.remove(_next);
  }

  @override
  bool get isActive => _delegate?.isActive ?? false;

  @override
  //offsetTicks + _delegate?.tick ?? 0;
  int get tick => throw UnimplementedError('tick');
}

/*
    Worried about this case:
    p scheduled every 2 sec
    t scheduled for 4 sec

    p is before t

    pause at 1 sec
    when resume

    p (as a timer) scheduled for 1 sec later
    t scheduled 3 sec later
    when p runs, schedules periodic for 2 sec

    now t is before p

    one soln might be to wait to schedule t until all peer p's before it are
    scheduled
    this would include new and paused t's.

    for all p
      for all t_scheduled_after_p
        if (p.willFireAt(t.duration)) {
          offsetPeriodic(p, peers: [t, ...]
          p.schedulePeer(t, t.duration)

    another is to schedule p at gcd of both remaining time and actual period,
    but only run callback at actual period. would also need to impl ticks
    differently.

    another might be to track order somehow so when t runs, it knows to let p
    go first?
    keep all timers, in order–we are doing this already
    when timer fires, check if current offset is after any periodics which , if so schedule in next future
    if not, run, and remove itself it is not periodic.
    if period, track offset it last ran (ticks?)
    maybe dont need to be so complicated. every time a timer runs, it just pulls
    of the next timer from the queue.
    so maintain an ordered queue.

    what if instead of cancelling, we let run, but let callbacks deal with
    pauses?
    cb:
    check pause time. if > 0, schedule new timer at pause time with pause
    offset.
    if this is periodic, have to schedule a timer that then schedules the
    periodic
    problem is reoordering is potentially dramatic if multiple timers fall on
    the same offset.
     */
