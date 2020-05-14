import 'dart:collection';

import 'package:meta/meta.dart';

import 'august.dart';
import 'src/event_stream.dart';

export 'src/event_stream.dart' show Events;

class StoryElements<O extends StoryElement, K> extends StoryElement {
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
    // TODO: available.putWhile(key, option, available);
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

abstract class Available {
  Scope get availability;
  bool get isAvailable => availability.isEntered;
  bool get isNotAvailable => availability.isNotEntered;
}
