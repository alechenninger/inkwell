import 'dart:async';
import 'dart:collection';

import 'core.dart';

export 'dart:async';

export 'core.dart' show Event;

// TODO consider removing generic type and simply use Event
class Events<T extends Event> {
  final EventStream<T> _stream = EventStream<T>();

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
  Future<U> event<U extends T>(U Function() event) {
    return Future(() {
      U theEvent;
      try {
        theEvent = event();
      } catch (e) {
        _stream.addError(e);
        rethrow;
      }
      _stream.add(theEvent);
      return theEvent;
    });
  }

  Future<U> eventValue<U extends T>(U event) {
    return Future(() {
      _stream.add(event);
      return event;
    });
  }

  void addTo(EventSink<T> sink) {
    stream.listen((e) => sink.add(e), onError: (e) => sink.addError(e));
  }

  void includeStoryElement(StoryElement<T> emitter) {
    includeStream(emitter.events);
  }

  void includeStream(Stream<T> stream) {
    // TODO subscriptions leaked
    stream.listen((t) => _stream.add(t), onError: (e) => _stream.addError(e));
  }

  void includeAll(Iterable<Stream<T>> streams) {
    streams.forEach(includeStream);
  }

//  void publishNow(T event) {
//    _stream.add(event);
//  }

  void done() {
    _stream.done();
  }
}

class EventStream<T extends Event> extends Stream<T> implements EventSink<T> {
  // Maintain separate listener lists, as it is important that async listeners
  // are scheduled before sync listeners are run. This is because sync listeners
  // may themselves schedule tasks, which should not become before the original
  // scheduled tasks. Think of this stream itself as the first of the
  // synchronous "reactions" – the listeners to this shouldn't skip ahead.
  var _asyncListeners = <_AsyncEventSubscription>[];
  var _syncListeners = <_SyncEventSubscription>[];

  final bool isBroadcast = true;

  _SynchronousEventStream<T> get asSynchronousStream =>
      _SynchronousEventStream<T>(this);

  @override
  StreamSubscription<T> listen(void Function(T event) onData,
      {Function onError, void Function() onDone, bool cancelOnError}) {
    var sub = _AsyncEventSubscription<T>()
      ..onData(onData)
      ..onDone(onDone);
    if (_asyncListeners != null) {
      _asyncListeners.add(sub);
    }
    return sub;
  }

  void add(T event) {
    if (_asyncListeners == null) {
      throw StateError('Cannot add event to done stream');
    }
    _asyncListeners.forEach((sub) => sub._add(event));
    _syncListeners.forEach((sub) => sub._add(event));
  }

  void addError(Object error, [StackTrace trace]) {
    if (_asyncListeners == null) {
      throw StateError('Cannot add error to done stream');
    }
    _asyncListeners.forEach((sub) => sub._addError(error));
    _syncListeners.forEach((sub) => sub._addError(error));
  }

  void includeStoryElement(StoryElement<T> emitter) {
    includeStream(emitter.events);
  }

  void includeAll(Iterable<Stream<T>> streams) {
    streams.forEach(includeStream);
  }

  void includeStream(Stream<T> stream) {
    // TODO subscriptions leaked
    stream.listen((t) => add(t), onError: (e) => addError(e));
  }

  void close() => done();

  void done() {
    // TODO: not sure if done logic around here is right
    _asyncListeners.forEach((sub) => sub._done());
    _syncListeners.forEach((sub) => sub._done());
    _asyncListeners = null;
    _syncListeners = null;
  }

  bool get isDone => _asyncListeners == null;
}

class _SynchronousEventStream<T> extends Stream<T> {
  final EventStream _backing;

  final bool isBroadcast = true;

  _SynchronousEventStream(this._backing);

  @override
  StreamSubscription<T> listen(void Function(T event) onData,
      {Function onError, void Function() onDone, bool cancelOnError}) {
    var sub = _SyncEventSubscription<T>()
      ..onData(onData)
      ..onDone(onDone);
    if (_backing._syncListeners != null) {
      _backing._syncListeners.add(sub);
    }
    return sub;
  }
}

abstract class _EventSubscription<T> extends StreamSubscription<T> {
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
    // TODO: just remove self from listeners list?
    _onData = null;
    _onDone = null;
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
    throw UnimplementedError('addError. got $error');
  }

  void _add(T event) {
    if (_isCanceled) return;
    if (_onData == null) return;
    if (!isPaused) {
      var cb = _onData;
      _dispatch(() {
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
    _dispatch(_onDone);
  }

  void _dispatch(void Function() fn);
}

class _AsyncEventSubscription<T> extends _EventSubscription<T> {
  void _dispatch(void Function() fn) {
    scheduleMicrotask(fn);
  }
}

class _SyncEventSubscription<T> extends _EventSubscription<T> {
  void _dispatch(Function fn) {
    fn();
  }
}
