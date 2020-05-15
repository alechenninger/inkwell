import 'src/core.dart';

export 'src/persistence.dart' hide FastForwarder;

abstract class UserInterface {
  Stream<Action> get actions;
  void play(Stream<Event> events);
}
