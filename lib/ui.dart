import 'src/events.dart';

abstract class UserInterface {
  Stream<Action> get actions;
  void play(Stream<Event> events);
}

abstract class Action<M> {
  Type get module => M;

  void run(M module);
}
