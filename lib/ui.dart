import 'package:august/august.dart';

import 'src/core.dart';

export 'src/persistence.dart' hide FastForwarder;

abstract class UserInterface {
  Stream<MetaAction> get metaActions;
  Stream<Action> get actions;

  /// Instruct the UI to play back these events and present them to the user (in
  /// whatever way the UI wants to interpret the events).
  ///
  /// [play] is called once per start of a story. The [events] stream emits a
  /// done event when no more events will be emitted.
  ///
  /// [play] must not be called while listening to an event stream that is not
  /// yet done.
  Future play(Stream<Event> events);
  Future get stopped;
}
