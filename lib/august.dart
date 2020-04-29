// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august;

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:quiver/check.dart';
import 'package:quiver/collection.dart';
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

// TODO: Consider a "StoryZone" which aggregates all capabilities for stories
//   another one that would be useful might be scaling times e.g 1 second is actually 2
///
class PausableZone {
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

  PausableZone(this._parentOffset, {Zone parent}) {
    parent = parent ?? Zone.current;
    _zone = parent.fork(
        specification: ZoneSpecification(
      createPeriodicTimer: pausablePeriodicTimer,
      createTimer: pausableTimer,
      scheduleMicrotask: pausableMicrotask,
    ));
  }

  void pause() {
    if (_pausedAt != null) return;
    _pausedAt = _parentOffset();

    for (var scheduled in _running.toList(growable: false)) {
      var timer = scheduled.timer;
      timer.pause();
    }
    // TODO: also microtasks
  }

  void resume() {
    /*
    schedule all microtasks
    */
    _pausedFor += _parentOffset() - _pausedAt;
    _pausedAt = null;

    _resumeUntilNextPeriodic();

    /*
    restart all timers with durations - elapsed pause duration

    drain timers in order (order by next call, scheduled order)
    if not periodic, schedule
    if periodic, stop draining, schedule timer at offset which will then schedule periodic
    and start draining again per above algorithm


     */
  }

  Timer pausableTimer(Zone self, ZoneDelegate parent, Zone zone,
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

  Timer pausablePeriodicTimer(Zone self, ZoneDelegate parent, Zone zone,
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

  void pausableMicrotask(
      Zone self, ZoneDelegate parent, Zone zone, void Function() f) {
    parent.scheduleMicrotask(zone, f);
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

        periodic.cancel();

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
  final PausableZone _zone;

  Controller(this._zone);

  void pause() {
    _zone.pause();
  }

  void resume() {
    _zone.resume();
  }

  Duration get parentOffset => _zone._parentOffset();

  Duration get offset => _zone.offset;
}

class _Scheduled implements Comparable<_Scheduled> {
  final Duration nextCall;
  final int sequence;
  final PausableTimer timer;
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

abstract class PausableTimer implements Timer {
  void pause();
}

class _PausableNonPeriodicTimer implements PausableTimer {
  final PausableZone _zone;
  final Timer Function(_PausableNonPeriodicTimer, Duration) _createTimer;
  _Scheduled _scheduled;
  Timer _delegate;
  bool _cancelled = false;

  _PausableNonPeriodicTimer(
      this._zone, int sequence, this._createTimer, Duration nextCall) {
    // TODO: consider modelling this more like periodic:
    //   don't create scheduled until started.
    //   maybe just take duration in start?
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

class _PausablePeriodicTimer implements PausableTimer {
  final PausableZone _zone;
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
