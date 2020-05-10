import 'dart:collection';
import 'dart:math';

import 'package:august/august.dart';
import 'package:meta/meta.dart';

import 'events.dart';
import 'scope.dart';

abstract class Actionable<U extends Event> with Available implements Emitter {
  final _events = Events();

  Stream<Event> get events => _events.stream;

  final U Function() _perform;

  Scope get availability;

  Actionable(this._perform);

  Future<U> perform() {
    return _events.event(() {
      if (isNotAvailable) {
        throw NotAvailableException(this);
      }

      return _perform();
    });
  }
}

class Used<T> extends Event {}

abstract class Available {
  Scope get availability;
  bool get isAvailable => availability.isEntered;
  bool get isNotAvailable => availability.isNotEntered;
}

abstract class Keyed<T> {
  T get key;
}

// TODO: better name
class ScopedEmitters<O extends Emitter, K> extends Emitter {
  final _available = <K, O>{};

  Map<K, O> get available => UnmodifiableMapView(_available);

  final _events = StreamController<Event>(sync: true);

  Stream<Event> get events => _events.stream;

  void add(O object, Scope available,
      {@required K key,
      @required Event Function() onAvailable,
      @required Event Function() onUnavailable}) {
    // TODO: why shouldnt availability events just be emitted from the object
    //   like other events?
    available.listen(onEnter: (_) {
      if (_available.containsKey(key)) {
        throw StateError('Object already available with key "$key"');
      }
      _available[key] = object;
      _events.add(onAvailable());
    }, onExit: (_) {
      _available.remove(key);
      _events.add(onUnavailable());
    });
    object.events
        .listen((e) => _events.add(e), onError: (e) => _events.addError(e));
  }
}

class Counted<U extends Event> extends Actionable<U> {
  final CountScope uses;
  Scope _availability;
  Scope get availability => _availability;

  Counted(U Function() use,
      {CountScope exclusiveWith, Scope available = always})
      : uses = exclusiveWith ?? CountScope(1),
        super(use) {
    _availability = available.and(uses);
  }

  Future<U> perform() async {
    var e = await super.perform();
    uses.increment();
    return e;
  }
}

class NotAvailableException {
  final unavailable;

  NotAvailableException(this.unavailable);

  String toString() => '$unavailable is not available for use';
}
