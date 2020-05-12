import 'input.dart';
import 'src/events.dart';

abstract class UserInterface {
  Stream<Action> get actions;
  void play(Stream<Event> events);
}
