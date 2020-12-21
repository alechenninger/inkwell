import 'package:built_value/serializer.dart';

/// A model of something that has happened, usually named in the past tense e.g.
/// ItemBought or PersonMoved, used primarily to notify players via a
/// user interface.
abstract class Event {}

/// A reified action taken that is runnable within some [StoryModule].
abstract class Action<M extends StoryModule> {
  Type get module => M;

  void run(M module);
}

/// An object interesting to the story which produces [Event]s, usually created
/// and maintained by a [StoryModule], which publishes these events to a user
/// interface.
abstract class StoryElement<T extends Event> {
  Stream<T> get events;
  // TODO: close?
}

/// An entry-point for story-telling functionality.
///
/// Provides arbitrary functionality for stories like dialog or items or
/// characters, etc., that is intended to be surfaced in some user interface
/// via [Event]s. This is usually done through one or more [StoryElement]s,
/// whose events are aggregated.
abstract class StoryModule<T extends Event> extends StoryElement<T> {
  Serializers get serializers;
}
