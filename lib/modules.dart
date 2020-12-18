/// Abstractions for assisting in the development of [StoryModules].
library august.modules;

import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

import 'august.dart';
import 'src/event_stream.dart';

export 'src/event_stream.dart' show EventStream;

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
  O add(O Function(EventStream<Event>) newO, Scope Function(O) availability,
      K Function(O) keyOf) {
    var object = newO(_events.childStream());
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

abstract class ScopedElement extends StoryElement with Available {}

abstract class Available {
  Scope get availability;

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

  /// A scope that is entered whenever this option is available.
  Scope get availability => _available;

  // TODO: Consider simply Stream<Option>
  Stream<U> get onUse => _onUse;

  final CountScope uses;
  final EventStream<U> _onUse;

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
      _events = events,
      _onUse = events.childStream<U>()
  {
    _available = available.and(this.uses);

    publishAvailability(_events,
          onEnter: () => onAvailable(this as E),
          onExit: () => onUnavailable(this as E));
  }

  /// Schedules option to be used at the end of the current event queue.
  ///
  /// The return future completes with success when the option is used and all
  /// listeners receive it. It completes with an error if the option is not
  /// available to be used.
  Future<U> use() {
    var event = _use(this as E);
    if (isAvailable) {
      _onUse.add(event);
      uses.increment();
    } else {
      throw _notAvailableException(this as E);
    }
    // or just don't return a future at all
    return _onUse.firstWhere((e) => e == event);

    // Wait to check isAvailable until option actually about to be used
    // var e = await _onUse.event(() {
    //   if (!isAvailable) {
    //     throw _notAvailableException(this as E);
    //   }
    //
    //   return _use(this as E);
    // });
    //
    // // This could be left out of a core implementation, and "uses" could be
    // // implemented as an extension by listening to the use() and a modified
    // // availability scope, as is done here.
    // uses.increment();
    //
    // return e;
  }
}
