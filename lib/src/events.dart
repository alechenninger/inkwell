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
