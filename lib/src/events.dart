part of '../august.dart';

// TODO: should use common supertype of T like `Event` or something like that?
class Events<T extends Event> {
  final _stream = _EventStream<T>();

  Stream<T> get stream => _stream;

  /// Schedules the function to run as the next event in the event loop. At that
  /// time, listeners will be scheduled in microtasks to receive the [event]
  /// functions return value.
  ///
  /// Listeners to this future, therefore, are fired before listeners of the
  /// event, because those event listeners are not scheduled until the future
  /// itself runs. Listeners to this future will be scheduled immediately.
  // TODO: should this return a future? It creates a way to listen to the event
  //   that isn't like regular listening mechanism.
  //   however, adds a way to add logic that fires after the event is added to
  //   the stream, without needing [post] parameter functionality.
  Future<T> event(T Function() event) {
    return Future(() {
      T theEvent;
      try {
        theEvent = event();
      } catch (e) {
        _stream._addError(e);
        rethrow;
      }
      _stream._add(theEvent);
      return theEvent;
    });
  }

  Future<T> eventValue(T event) {
    return Future(() {
      _stream._add(event);
      return event;
    });
  }

//  void publishNow(T event) {
//    _stream._add(event);
//  }

  void done() {
    _stream._done();
  }
}

abstract class Event {}

class _EventStream<T> extends Stream<T> {
  var _listeners = <_EventSubscription>[];
  var _syncStreams = <_SynchronousEventStream>[];

  final bool isBroadcast = true;

  _SynchronousEventStream<T> get synchronous {
    var sync = _SynchronousEventStream<T>();
    _syncStreams.add(sync);
    return sync;
  }

  @override
  StreamSubscription<T> listen(void Function(T event) onData,
      {Function onError, void Function() onDone, bool cancelOnError}) {
    var sub = _EventSubscription<T>()
      ..onData(onData)
      ..onDone(onDone);
    if (_listeners != null) {
      _listeners.add(sub);
    }
    return sub;
  }

  void _add(T event) {
    if (_listeners == null) {
      throw StateError('Cannot add event to done stream');
    }
    _listeners.forEach((sub) => sub._add(event));
    _syncStreams.forEach((s) => s._add(event));
  }

  void _addError(dynamic error) {
    if (_listeners == null) {
      throw StateError('Cannot add error to done stream');
    }
    _listeners.forEach((sub) => sub._addError(error));
    _syncStreams.forEach((s) => s._addError(error));
  }

  void _done() {
    // TODO: not sure if done logic around here is right
    _listeners.forEach((sub) => sub._done());
    _syncStreams.forEach((s) => s._done());
    _syncStreams = null;
    _listeners = null;
  }

  bool get _isDone => _listeners == null;
}
class _SynchronousEventStream<T> extends Stream<T> {
  var _listeners = <_SynchronousEventSubscription>[];

  final bool isBroadcast = true;

  @override
  StreamSubscription<T> listen(void Function(T event) onData,
      {Function onError, void Function() onDone, bool cancelOnError}) {
    var sub = _SynchronousEventSubscription<T>()
      ..onData(onData)
      ..onDone(onDone);
    if (_listeners != null) {
      _listeners.add(sub);
    }
    return sub;
  }

  void _add(T event) {
    if (_listeners == null) {
      throw StateError('Cannot add event to done stream');
    }
    _listeners.forEach((sub) => sub._add(event));
  }

  void _addError(dynamic error) {
    if (_listeners == null) {
      throw StateError('Cannot add error to done stream');
    }
    _listeners.forEach((sub) => sub._addError(error));
  }

  void _done() {
    // TODO: not sure if done logic around here is right
    _listeners.forEach((sub) => sub._done());
    _listeners = null;
  }

  bool get _isDone => _listeners == null;
}
//
//class _MergedStream<T> extends Stream<T> {
//  final Stream<T> _first;
//  final Stream<T> _second;
//
//  _MergedStream(this._first, this._second);
//
//  @override
//  StreamSubscription<T> listen(void Function(T event) onData,
//      {Function onError, void Function() onDone, bool cancelOnError}) {
//    return _MergedSubscription(_first.listen(onData), _second.listen(onData));
//  }
//}
//
//class _MergedSubscription<T> extends StreamSubscription<T> {
//  final StreamSubscription<T> _first;
//  final StreamSubscription<T> _second;
//
//  _MergedSubscription(this._first, this._second);
//
//  @override
//  Future<E> asFuture<E>([E futureValue]) {
//    // TODO: review
//    return Future.any(
//        [_first.asFuture(futureValue), _second.asFuture(futureValue)]);
//  }
//
//  @override
//  Future cancel() {
//    return Future.wait([_first.cancel(), _second.cancel()]);
//  }
//
//  @override
//  bool get isPaused => _first.isPaused;
//
//  @override
//  void onData(void Function(T data) handleData) {
//    _first.onData(handleData);
//    _second.onData(handleData);
//  }
//
//  @override
//  void onDone(void Function() handleDone) {
//    _first.onDone(handleDone);
//    _second.onDone(handleDone);
//  }
//
//  @override
//  void onError(Function handleError) {
//    _first.onError(handleError);
//    _second.onError(handleError);
//  }
//
//  @override
//  void pause([Future resumeSignal]) {
//    // TODO: review this
//    var broadcast = resumeSignal.asStream().asBroadcastStream();
//    _first.pause(broadcast.first);
//    _second.pause(broadcast.first);
//  }
//
//  @override
//  void resume() {
//    _first.resume();
//    _second.resume();
//  }
//}

class _EventSubscription<T> extends StreamSubscription<T> {
  void Function(T) _onData;
  void Function() _onDone;
  var _pauses = 0;
  var _buffer = Queue<T>();
  var _isCanceled = false;
  var _isDone = false;

  @override
  Future<E> asFuture<E>([E futureValue]) {
    // TODO: implement asFuture
    throw UnimplementedError();
  }

  @override
  Future cancel() {
    _onData = null;
    _buffer = null;
    _pauses = 0;
    _isCanceled = true;
    return Future.value();
  }

  @override
  bool get isPaused => _pauses > 0;

  @override
  void onData(void Function(T data) handleData) {
    _onData = handleData;
  }

  @override
  void onDone(void Function() handleDone) {
    _onDone = handleDone;
  }

  @override
  void onError(Function handleError) {
    throw UnimplementedError();
  }

  @override
  void pause([Future resumeSignal]) {
    if (_isCanceled) return;
    _pauses++;
  }

  @override
  void resume() {
    if (!isPaused || _isCanceled) return;
    _pauses--;
    // TODO: reschedule events
    throw UnimplementedError();
  }

  void _addError(dynamic error) {
    // TODO
  }

  void _add(T event) {
    if (_isCanceled) return;
    if (_onData == null) return;
    if (!isPaused) {
      var cb = _onData;
      scheduleMicrotask(() {
        if (!isPaused && !_isCanceled) {
          cb(event);
        }
      });
    } else {
      _buffer.add(event);
    }
  }

  void _done() {
    // TODO: is this logic right?
    if (_isDone) return;
    _isDone = true;
    if (_onDone == null) return;
    var cb = _onDone;
    scheduleMicrotask(() {
      cb();
    });
  }
}


class _SynchronousEventSubscription<T> extends StreamSubscription<T> {
  void Function(T) _onData;
  void Function() _onDone;
  var _pauses = 0;
  var _buffer = Queue<T>();
  var _isCanceled = false;
  var _isDone = false;

  @override
  Future<E> asFuture<E>([E futureValue]) {
    // TODO: implement asFuture
    throw UnimplementedError();
  }

  @override
  Future cancel() {
    _onData = null;
    _buffer = null;
    _pauses = 0;
    _isCanceled = true;
    return Future.value();
  }

  @override
  bool get isPaused => _pauses > 0;

  @override
  void onData(void Function(T data) handleData) {
    _onData = handleData;
  }

  @override
  void onDone(void Function() handleDone) {
    _onDone = handleDone;
  }

  @override
  void onError(Function handleError) {
    throw UnimplementedError();
  }

  @override
  void pause([Future resumeSignal]) {
    if (_isCanceled) return;
    _pauses++;
  }

  @override
  void resume() {
    if (!isPaused || _isCanceled) return;
    _pauses--;
    // TODO: reschedule events
    throw UnimplementedError();
  }

  void _addError(dynamic error) {
    // TODO
  }

  void _add(T event) {
    if (_isCanceled) return;
    if (_onData == null) return;
    if (!isPaused) {
      _onData(event);
    } else {
      _buffer.add(event);
    }
  }

  void _done() {
    // TODO: is this logic right?
    if (_isDone) return;
    _isDone = true;
    if (_onDone == null) return;
    _onDone();
  }
}
