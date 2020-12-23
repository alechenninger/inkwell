import 'package:built_value/serializer.dart';

import 'august.dart';
import 'src/core.dart';

export 'src/persistence.dart' hide FastForwarder;

abstract class UserInterface {
  Stream<Interrupt> get interrupts;

  // TODO: better name
  void notice(Stream<Notice> notices);

  Stream<Action> get actions;

  /// Instruct the UI to play back these events and present them to the user (in
  /// whatever way the UI wants to interpret the events).
  ///
  /// [play] is called once per start of a story. The [events] stream emits a
  /// done event when no more events will be emitted.
  ///
  /// [play] must not be called while listening to an event stream that is not
  /// yet done.
  void play(Stream<Event> events);

  // TODO: move to return value of play like StreamConsumer.addStream
  Future get stopped;
}

class RemoteUserInterface implements UserInterface {
  final Serializers _serializers;

  RemoteUserInterface(this._serializers);

  @override
  // TODO: receive over the wire, deserialize
  Stream<Action> get actions => throw UnimplementedError();

  @override
  Future play(Stream<Event> events) {}

  @override
  // TODO: implement metaActions
  Stream<Interrupt> get interrupts => throw UnimplementedError();

  @override
  // TODO: implement stopped
  Future get stopped => throw UnimplementedError();

  @override
  void notice(Stream<Notice> notices) {
    // TODO: implement notice
  }
}
