part of '../august.dart';

// TODO: should use common supertype of T like `Event` or something like that?
class Events<T extends Event> {
  final _stream = _EventStream<T>();

  Stream<T> get stream => _stream;

  /// Schedules the function to run as the next event in the event loop,
  // TODO: should this return a future? It creates a way to listen to the event
  //   that isn't like regular listening mechanism.
  Future<T> publish(T Function() event) {
    return Future(() {
      try {
        var theEvent = event();
        _stream._add(theEvent);
        return theEvent;
      } catch (e) {
        // TODO: add error to stream
        rethrow;
      }
    });
  }

  void publishValue(T event) {
    Future(() => _stream._add(event));
  }

  void publishNow(T event) {
    _stream._add(event);
  }

  void done() {
    _stream._done();
  }
}

abstract class Event<T> {

}

class _EventStream<T> extends Stream<T> {
  var _listeners = <_EventSubscription>[];

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
  }

  void _done() {
    // TODO: not sure if done logic around here is right
    _listeners.forEach((sub) => sub._done());
    _listeners = null;
  }

}

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
