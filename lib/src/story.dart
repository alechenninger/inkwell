import 'events.dart';

class Story {
  Events<T> newEventStream<T extends Event>() {
    return Events<T>();
  }
}
