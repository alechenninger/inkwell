/// Abstractions for assisting in the development of [StoryModules].
library august.modules;

import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

import 'august.dart';
import 'src/event_stream.dart';

export 'src/event_stream.dart' show Events;

class ScopedElements<O extends StoryElement, K> extends StoryElement {
  final _available = <K, O>{};

  Map<K, O> get available => UnmodifiableMapView(_available);

  final _events = StreamController<Event>.broadcast(sync: true);

  Stream<Event> get events => _events.stream;

  void add(O object, Scope available, {@required K key}) {
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

    object.events.listen((e) => _events.add(e),
        onError: (e) => _events.addError(e), onDone: () => _events.close());
  }

  void _add(K key, O object) {
    if (_available.containsKey(key)) {
      throw StateError('Element already available with key "$key"');
    }
    _available[key] = object;
  }
}

abstract class Available {
  Scope get availability;
  bool get isAvailable => availability.isEntered;
  bool get isNotAvailable => availability.isNotEntered;
}

class LimitedUseElement<E extends LimitedUseElement<E, U>, U extends Event>
    extends StoryElement with Available {
  int get maxUses => uses.max;
  int get useCount => uses.count;

  Scope _available;

  bool get isAvailable => _available.isEntered;

  /// A scope that is entered whenever this option is available.
  Scope get availability => _available;

  // TODO: Consider simply Stream<Option>
  Stream<U> get onUse => _onUse.stream;

  final CountScope uses;
  final _onUse = Events<U>();

  Stream<Event> _events;
  Stream<Event> get events => _events;

  final U Function(E) _use;
  final dynamic Function(E) _notAvailableException;

  LimitedUseElement({
    CountScope uses,
    Scope available = always,
    @required U Function(E) use,
    @required Object Function(E) unavailableUse,
    @required Event Function(E) onAvailable,
    @required Event Function(E) onUnavailable,
  })  : uses = uses ?? CountScope(1),
        _use = use,
        _notAvailableException = unavailableUse {
    _available = available.and(this.uses);
    _events = Rx.merge([
      _available.toStream(
          onEnter: () => onAvailable(this as E),
          onExit: () => onUnavailable(this as E)),
      _onUse.stream
    ]).asBroadcastStream();
  }

  /// Schedules option to be used at the end of the current event queue.
  ///
  /// The return future completes with success when the option is used and all
  /// listeners receive it. It completes with an error if the option is not
  /// available to be used.
  Future<U> use() async {
    // Wait to check isAvailable until option actually about to be used
    var e = await _onUse.event(() {
      if (!isAvailable) {
        throw _notAvailableException(this as E);
      }

      return _use(this as E);
    });

    // This could be left out of a core implementation, and "uses" could be
    // implemented as an extension by listening to the use() and a modified
    // availability scope, as is done here.
    uses.increment();

    return e;
  }
}
