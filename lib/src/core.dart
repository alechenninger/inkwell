import 'package:built_value/serializer.dart';
import 'package:rxdart/rxdart.dart';

/// A model of something that has happened, usually named in the past tense e.g.
/// ItemBought or PersonMoved, used primarily to notify players via a
/// user interface.
abstract class Event {}

/// A reified action taken that is performed by some [Ink].
abstract class Action<I extends Ink> {
  Type get inkType => I;

  void perform(I ink);
}

/// An object interesting to the story which produces [Event]s, usually created
/// and maintained by a [Ink], which publishes these events to a user
/// interface.
// TODO: may not really need this abstraction? it may be simpler to always
//  aggregate an elements events through its Ink.
abstract class StoryElement<T extends Event> {
  Stream<T> get events;
}

/// An entry-point for story-telling functionality.
///
/// Provides arbitrary functionality for stories like dialog or items or
/// characters, etc., that is intended to be surfaced in some user interface
/// via [Event]s. This is usually done through one or more [StoryElement]s,
/// whose events are aggregated.
abstract class Ink<T extends Event> extends StoryElement<T> {
  Serializers get serializers;
  Future close();
}

typedef Script = void Function(Palette);

/// A complete and useful aggregate of [Ink]s used for writing scripts.
///
/// Various [Ink]s (and their functionality) can be accessed by type by calling
/// the Palette as a generic function, e.g. `palette<Dialog>()`
///
/// The events produced by [Ink]s are accessible from the [events] broadcast
/// stream.
class Palette {
  Map<Type, Ink> _inks;
  Stream<Event> _events;
  Serializers _serializers;

  Palette(Iterable<Ink> m) {
    // TODO: validate that no two inks share the same type
    _inks = m.fold<Map<Type, Ink>>(<Type, Ink>{},
            (map, ink) => map..[ink.runtimeType] = ink);
    _events = Rx.merge(inks.map((m) => m.events));
    _serializers = Serializers.merge(inks.map((m) => m.serializers));
  }

  T call<T>() => _inks[T] as T;

  Ink operator [](Type t) => _inks[t];

  Iterable<Ink> get inks => _inks.values;

  Stream<Event> get events => _events;

  Serializers get serializers => _serializers;

  Future close() => Future.wait(inks.map((m) => m.close()));
}
