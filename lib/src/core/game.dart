// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

abstract class Game {
  void begin();

  void addActor(Type a) => broadcast(new AddActor(a.toString()));

  void addOption(Option option) => broadcast(new AddOption(option));

  void broadcast(Event event) => broadcastDelayed(const Duration(), event);

  void broadcastDelayed(Duration delay, Event event);

  void subscribe(String listenerName, Type actorType,
      {EventFilter filter: const AllEvents()});
}

class _Game extends Game {
  // Current state
  List<Option> _options;
  List<Subscription> _subscriptions;
  List<PendingEvent> _pendingEvents;

  final Duration _offset = const Duration();
  final Stopwatch _stopwatch = new Stopwatch();

  final StreamController<Event> _ctrl =
      new StreamController.broadcast(sync: true);

  final Script _script;

  _Game(this._script) {
    _ctrl.stream
        .firstWhere((e) => e is BeginEvent)
        .then((e) => _stopwatch.start());

    _options = [];
    _subscriptions = [];
    _pendingEvents = [];

    _addGameEventHandlers();
  }

  _Game.fromJson(Map json, this._script)
      : _offset = new Duration(microseconds: json["offset"]) {
    if (!_isCompatible(json, _script)) {
      throw new ArgumentError("Json is not compatible with script.");
    }

    _options =
        json["options"].map((o) => new Option.fromJson(o, _script)).toList();

    json["subscriptions"]
        .map((s) => new Subscription.fromJson(s, _script))
        .forEach(_addSubscription);

    _addGameEventHandlers();

    json["pendingEvents"]
        .map((s) => new PendingEvent.fromJson(s, _script))
        .forEach((e) => broadcastDelayed(e.offset, e.event));

    _stopwatch.start();
  }

  void _addGameEventHandlers() {
    _ctrl.stream
        .where((e) => e is AddActor)
        .listen((AddActor e) => _script.getActor(e.actor, this).onAdd());
  }

  void begin() {
    broadcast(new BeginEvent());
  }

  void broadcastDelayed(Duration delay, Event event) {
    _pendingEvents.add(new PendingEvent(delay, event));
    new Future.delayed(delay, () => _addEvent(event));
  }

  /// Subscribes to the next (and only the next) event that matches filter.
  // TODO: Handle long-running subscriptions? (Not just first matching)
  void subscribe(String listenerName, Type actorType,
      {EventFilter filter: const AllEvents()}) {
    // TODO: Review use of String vs Type
    _addSubscription(new Subscription(filter, listenerName, "$actorType"));
  }

  /// Adds a [Stream] listener based on the [subscription]. The `subscription`
  /// is added to [_subscriptions] and removed from when the first relevant
  /// event is fired.
  void _addSubscription(Subscription subscription) {
    _subscriptions.add(subscription);

    subscription.filter.filter(_ctrl.stream).first.then((e) {
      _subscriptions.remove((s) => s.id == subscription.id);
      subscription.getListener(this, _script)(e);
    });
  }

  void _addEvent(Event event) {
    _pendingEvents.removeWhere((e) => e.id == event.id);
    // TODO: Do we need timestamps?
    event._timeStamp = _stopwatch.elapsed;
    _ctrl.add(event);
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

/// Tests that the json representation of this game is compatible with the
/// provided [script].
bool _isCompatible(Map json, Script script) {
  var scriptInfo = json["script"];
  var name = scriptInfo["name"];
  var version = scriptInfo["version"];
  return name == script.name && version == script.version;
}
