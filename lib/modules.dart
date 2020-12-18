/// Abstractions for assisting in the development of [StoryModules].
library august.modules;

import 'dart:collection';

import 'package:meta/meta.dart';

import 'august.dart';
import 'src/event_stream.dart';

export 'src/event_stream.dart' show EventStream;

/// [ScopedElements] assists in the construction of a collection of story
/// elements synchronized with the elements' availability [Scope], as well as
/// aggregating all elements' events into a single stream.
class ScopedElements<O extends StoryElement, K> extends StoryElement {
  final _available = <K, O>{};

  Map<K, O> get available => UnmodifiableMapView(_available);

  final EventStream<Event> _events;
  Stream<Event> get events => _events;

  ScopedElements([EventStream<Event> events])
      : _events = events ?? EventStream<Event>();

  // TODO: use type which has all of these things already?
  //   Or is this more flexible because it doesn't require a subtype
  //   relationship?
  /// Creates and watches an instance created by [newO]. When it is available,
  /// based on [availability], it is included in [available] collection,
  /// referencable by the key returned by [keyOf].
  ///
  /// [newO] is a function which accepts an [EventStream] and creates an
  /// instance of [O]. The instance must publish its events to this
  /// `EventStream`.
  O add(O Function(EventStream<Event>) newO, Scope Function(O) availability,
      K Function(O) keyOf) {
    var object = newO(_events);
    var available = availability(object);
    var key = keyOf(object);

    if (available.isEntered) {
      _add(key, object);
    }

    // As this list is a *function* of the observed value, we use synchronous
    // values stream to avoid event listeners observing inconsistencies.
    available.asObserved.values.listen((inScope) {
      if (inScope) {
        _add(key, object);
      } else {
        _available.remove(key);
      }
    });

    return object;
  }

  void _add(K key, O object) {
    if (_available.containsKey(key)) {
      throw StateError('Element already available with key "$key"');
    }
    _available[key] = object;
  }
}

// TODO: fill this out. maybe?
abstract class ScopedElement extends StoryElement with Available {}

abstract class Available {
  Scope get availability;

  // TODO: consider moving out into ScopedElement or top-level function
  void publishAvailability(EventStream events,
      {@required Event Function() onEnter, @required Event Function() onExit}) {
    events
        .includeStream(availability.toStream(onEnter: onEnter, onExit: onExit));
    if (isAvailable) events.add(onEnter());
  }

  bool get isAvailable => availability.isEntered;
  bool get isNotAvailable => availability.isNotEntered;
}

class LimitedUseElement<E extends LimitedUseElement<E, U>, U extends Event>
    extends StoryElement with Available {
  int get maxUses => uses.max;
  int get useCount => uses.count;

  Scope _available;

  /// A scope that is entered whenever this element is available for use.
  Scope get availability => _available;

  final CountScope uses;

  EventStream<U> _onUse;
  Stream<U> get onUse => _onUse;

  final EventStream<Event> _events;
  Stream<Event> get events => _events;

  final U Function(E) _use;
  final dynamic Function(E) _notAvailableException;

  LimitedUseElement({
    CountScope uses,
    Scope available = always,
    @required EventStream<Event> events,
    @required U Function(E) use,
    @required Object Function(E) unavailableUse,
    @required Event Function(E) onAvailable,
    @required Event Function(E) onUnavailable,
  })  : uses = uses ?? CountScope(1),
        _use = use,
        _notAvailableException = unavailableUse,
        _events = events.childStream() {
    _onUse = _events.childStream<U>();
    _available = available.and(this.uses);

    publishAvailability(_events,
        onEnter: () => onAvailable(this as E),
        onExit: () => onUnavailable(this as E));
  }

  /// Triggers the on use event for the element.
  ///
  /// Throws an exception if the element is not available.
  void use() {
    if (!isAvailable) {
      throw _notAvailableException(this as E);
    }

    _onUse.add(_use(this as E));
    uses.increment();
  }
}
