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

abstract class Identifiable {
  Id get id;
}

class Id {
  final String value;

  Id.of(this.value);

  // See https://github.com/Daegalus/dart-uuid/blob/master/lib/uuid_util.dart
  // for more bits of random example
  Id(): this.of(Random().nextInt(4294967296).toRadixString(36));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Id &&
              runtimeType == other.runtimeType &&
              value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

// TODO: better name
class ScopedEmitters<O extends Emitter> {
  final _available = <Id, O>{};

  Map<Id, O> get available => UnmodifiableMapView(_available);

  final _events = StreamController<Event>(sync: true);

  Stream<Event> get events => _events.stream;

  void add(O object, Scope available, Id id, Event Function() onAvailable) {
    // TODO: why shouldnt availability events just be emitted from the object
    //   like other events?
    available.listen(onEnter: (_) {
      _available[id] = object;
      _events.add(onAvailable());
    }, onExit: (_) {
      _available.remove(id);
      _events.add(Removed<O>(id));
    });
    object.events
        .listen((e) => _events.add(e), onError: (e) => _events.addError(e));
  }
}

class Removed<T> extends Event {
  final Id id;

  Removed(this.id);
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
