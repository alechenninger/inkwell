part of '../august.dart';

// TODO: should use common supertype of T like `Event` or something like that?
class Events<T> {
  var _stream = _EventStream<T>();

  Stream<T> get stream => _stream;

  /// Schedules the function to run as the next event in the event loop,
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

  void done() {
    _stream = null;
  }
}

class _EventStream<T> extends Stream<T> {
  final _listeners = <_EventSubscription>[];

  @override
  StreamSubscription<T> listen(void Function(T event) onData,
      {Function onError, void Function() onDone, bool cancelOnError}) {
    var sub = _EventSubscription<T>()
        ..onData(onData);
    _listeners.add(sub);
    return sub;
  }

  void _add(T event) {
    _listeners.forEach((sub) => sub._add(event));
  }

}

class _EventSubscription<T> extends StreamSubscription<T> {
  void Function(T) _onData;
  var _pauses = 0;
  var _buffer = Queue<T>();
  var _canceled = false;

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
    _canceled = true;
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
    throw UnimplementedError();
  }

  @override
  void onError(Function handleError) {
    throw UnimplementedError();
  }

  @override
  void pause([Future resumeSignal]) {
    if (_canceled) return;
    _pauses++;
  }

  @override
  void resume() {
    if (!isPaused || _canceled) return;
    _pauses--;
    // TODO: reschedule events
    throw UnimplementedError();
  }

  void _add(T event) {
    if (_canceled) return;
    if (!isPaused) {
      scheduleMicrotask(() {
        if (!isPaused && !_canceled) {
          _onData(event);
        }
      });
    } else {
      _buffer.add(event);
    }
  }
}
