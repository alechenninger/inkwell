// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

abstract class Game {
  void begin();

  void addActor(Actor a) {
    return broadcast(new AddActor(a));
  }

  void addOption(Option option) => broadcast(new AddOption(option));

  void broadcast(Event event);

  void broadcastDelayed(Duration delay, Event event);

  void subscribe(String listenerName, Type actorType,
      {EventFilter filter: const AllEvents()});
}

class _Game extends Game {
  // Current state
  List<Option> _options;
  List<Subscription> _subscriptions;
  List<PendingEvent> _pendingEvents;

  final Duration _offset;
  final Stopwatch _stopwatch = new Stopwatch();

  final StreamController<Event> _ctrl =
      new StreamController.broadcast(sync: true);

  final Script _script;

  _Game(this._script) : _offset = new Duration() {
    _ctrl.stream
        .firstWhere((e) => e is BeginEvent)
        .then((e) => _stopwatch.start());

    _addListeners();
  }

  _Game.fromJson(Map json, this._script)
      : _offset = new Duration(microseconds: json["offset"]) {
    _options =
        json["options"].map((o) => new Option.fromJson(o, _script)).toList();

    _subscriptions = json["subscriptions"]
        .map((s) => new Subscription.fromJson(s, _script))
        .toList();

    _pendingEvents = json["pendingEvents"]
        .map((s) => new PendingEvent.fromJson(s, _script))
        .toList();

    _addListeners();

    _pendingEvents.forEach((e) => broadcastDelayed(e.offset, e.event));

    _stopwatch.start();
  }

  void _addListeners() {
    _ctrl.stream.where((e) => e is AddActor)
        .listen((AddActor e) => _script.getActor(e.actor, this).onAdd());
  }

  void begin() {
    broadcast(new BeginEvent());
  }

  void broadcast(Event event) {
    new Future(() => _ctrl.add(event));
  }

  void broadcastDelayed(Duration delay, Event event) {
    new Future.delayed(delay, () => _ctrl.add(event));
  }

  void subscribe(String listenerName, Type actorType,
      {EventFilter filter: const AllEvents()}) {
    filter.filter(_ctrl.stream).listen(
        (e) => _script.getActor("$actorType", this).listeners[listenerName](e));
  }
}

class PendingEvent extends JsonEncodable {
  final Duration offset;
  final Event event;

  PendingEvent(this.offset, this.event);

  PendingEvent.fromJson(Map json, Script script)
      : offset = new Duration(microseconds: json["schedule"]),
        event = script.getEvent(json["event"]);

  Map toJson() => {"schedule": offset.inMicroseconds, "event": event};
}
