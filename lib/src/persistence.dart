import 'dart:async';
import 'dart:collection';

abstract class Archive {

  Version? operator [](String version);

  void save(Version version);

  List<Version> get versions;

  bool remove(String version);
}

class InMemoryArchive extends Archive {
  final _versions = <String, Version>{};

  @override
  Version operator [](String version) {
    return Version.copy(_versions.putIfAbsent(version, () => Version(version)));
  }

  @override
  List<Version> get versions =>
      _versions.values.map((e) => Version.copy(e)).toList(growable: false);

  @override
  bool remove(String version) {
    return _versions.remove(version) != null;
  }

  @override
  void save(Version version) {
    _versions[version.name] = Version.copy(version);
  }
}

class Version {
  final List<OffsetAction> _actions;

  final String name;

  Version(this.name) : _actions = <OffsetAction>[];

  Version.copy(Version v, {String? name}): this.started(name ?? v.name, v.actions);

  Version.started(this.name, List<OffsetAction> actions)
      : _actions = List.from(actions);

  List<OffsetAction> get actions => List.unmodifiable(_actions);

  void record(Duration offset, Object action) {
    print('persist: $offset $action');
    // TODO: could validate offset > last offset?
    _actions.add(OffsetAction(offset, action));
  }
}

class OffsetAction {
  final Duration offset;
  final Object action;

  OffsetAction(this.offset, this.action);

  OffsetAction.fromJson(Map<String, Object> json)
      : action = json['action']!,
        offset = Duration(milliseconds: json['offsetMillis'] as int);

  Map<String, Object> toJson() =>
      {'action': action, 'offsetMillis': offset.inMilliseconds};
}

// Adapted from quiver's FakeAsync
class FastForwarder {
  Zone? _zone;
  Duration _elapsed = Duration.zero;
  Duration? _elapsingTo;
  final Queue<Function> _microtasks = Queue();
  final Set<_FastForwarderTimer> _timers = <_FastForwarderTimer>{};
  bool _useParentZone = true;
  late Duration _switchedToParent;
  final Duration Function() _parentOffset;

  FastForwarder(this._parentOffset) {
    _switchedToParent = _parentOffset();
  }

  Duration get currentOffset => _useParentZone
      ? _elapsed + _parentOffset() - _switchedToParent
      : _elapsed;

  bool get isFastForwarding => !_useParentZone;

  void runFastForwardable(Function(FastForwarder) callback) {
    _useParentZone = false;
    _zone ??= Zone.current.fork(specification: _zoneSpec);
    _zone!.run(() => callback(this));
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
    _runTimersUntil(_elapsingTo!);
    _elapseTo(_elapsingTo!);
    _elapsingTo = null;
  }

  void switchToParentZone() {
    _useParentZone = true;
    _switchedToParent = _parentOffset();

    while (_microtasks.isNotEmpty) {
      _zone!.parent!.scheduleMicrotask(_microtasks.removeFirst() as Callback);
    }

    while (_timers.isNotEmpty) {
      var t = _timers.first;
      if (t.isPeriodic) {
        // TODO: I think this has side effect of reordering timers, because a
        //   non-periodic timer at same time will run before a periodic timer
        //   where it might not have otherwise
        _zone!.parent!.createTimer(t.nextCall - _elapsed, () {
          var trackingTimer = _TrackingTimer();
          t.callback(trackingTimer);
          if (trackingTimer.isActive) {
            _zone!.parent!
                .createPeriodicTimer(t.duration, t.callback as TimerCallback);
          }
        });
      } else {
        _zone!.parent!.createTimer(t.nextCall - _elapsed, t.callback as Callback);
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
    _FastForwarderTimer? next;
    while ((next = _getNextTimer()) != null && next!.nextCall <= elapsingTo) {
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

  _FastForwarderTimer? _getNextTimer() => _timers.isEmpty
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
  late Duration nextCall;

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
