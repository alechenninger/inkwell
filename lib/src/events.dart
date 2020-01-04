part of '../august.dart';

class StreamPublisher<T> {
  final _ctrl = StreamController<T>.broadcast(sync: true);

  Stream<T> get events => _ctrl.stream;

  Future<T> publish(T event,
      {void Function() check, void Function() sideEffects}) {
    try {
      check();
    } on Exception catch(e) {
      return Future.error(e);
    }

    sideEffects();

    return Future(() {
      _ctrl.add(event);
      return event;
    });
  }
}

class Publisher<T> {
  final _ctrl = Completer<T>.sync();

  Future<T> get event => _ctrl.future;

  Future<T> publish(T event,
      {void Function() check, void Function() sideEffects}) {
    try {
      check();
    } on Exception catch(e) {
      return Future.error(e);
    }

    sideEffects();

    return Future(() {
      _ctrl.complete(event);
      return event;
    });
  }
}

class Events<T> {

}

class _EventStream<T> extends Stream<T> {
  @override
  StreamSubscription<T> listen(void Function(T event) onData, {Function onError, void Function() onDone, bool cancelOnError}) {
    // TODO: implement listen
    return null;
  }

}

class _EventSubscription<T> extends StreamSubscription<T> {
  @override
  Future<E> asFuture<E>([E futureValue]) {
    // TODO: implement asFuture
    return null;
  }

  @override
  Future cancel() {
    // TODO: implement cancel
    return null;
  }

  @override
  // TODO: implement isPaused
  bool get isPaused => null;

  @override
  void onData(void Function(T data) handleData) {
    // TODO: implement onData
  }

  @override
  void onDone(void Function() handleDone) {
    // TODO: implement onDone
  }

  @override
  void onError(Function handleError) {
    // TODO: implement onError
  }

  @override
  void pause([Future resumeSignal]) {
    // TODO: implement pause
  }

  @override
  void resume() {
    // TODO: implement resume
  }

}
