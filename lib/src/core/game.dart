// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

abstract class Game implements JsonEncodable {
  /// Adds [actors] to the game, calling their [Actor.beforeBegin] callbacks
  /// before firing off a [BeginEvent]. Actors should use `beforeBegin` to
  /// register event handlers, and `onBegin` to fire events if necessary.
  // TODO: use a factory constructor instead of static factory method
  static Game newGame(Registry registry) {
    return new _Game(registry);
  }

  Future begin();

  Future addActor(dynamic a) {
    return broadcast(new AddActor(a));
  }

  Future addActors(List actors) {
    var broadcastActors = actors.map((a) => broadcast(new AddActor(a)));

    return Future.wait(broadcastActors);
  }

  Future addOption(Option option) {
    return broadcast(new AddOption(option));
  }

  /// Schedule a new event to be broadcast to all registered listeners. The
  /// event will not be broadcast immediately, but some time after the current
  /// event loop cycle is done.
  ///
  /// It is an error to broadcast an [Event] before [begin] is called.
  ///
  /// Returns a [Future] that completes with the event when it is broadcast to
  /// all listeners.
  Future<Event> broadcast(Event event);

  /// Schedule a new event to be broadcast to all registered listeners after
  /// the provided [Duration]. If it is 0 or less, it behaves as [broadcast].
  ///
  /// It is an error to broadcast an [Event] before [begin] is called.
  ///
  /// Returns a [Future] that completes with the event when it is broadcast to
  /// all listeners.
  Future<Event> broadcastDelayed(Duration delay, Event event);

  void subscribe(String listenerName, Type actorType,
      {EventFilter filter: const AllEvents()});
}

class _Game extends Game {
  final Registry _registry;

  /// Main broadcast stream controller which serves an [Event] sink as well as
  /// the [Stream] of [Event]s. Listening and broadcasting events is the
  /// central mechanic of communicating between actors and changing state.
  final StreamController<Event> _ctrl =
      new StreamController.broadcast(sync: true);

  final Stopwatch _stopwatch = new Stopwatch();

  final Map<String, JsonEncodable> _actors = {};

  bool _hasBegun = false;

  _Game(this._registry);

  Future begin() {
    _hasBegun = true;
    _stopwatch.start();
    return broadcast(new BeginEvent());
  }

  Future broadcast(Event e) {
    if (_hasBegun) {
      // Thanks, Günter! http://stackoverflow.com/a/29070144/2216134
      return new Future(() => _addEvent(e));
    } else {
      // TODO: should `then` broadcast or _addEvent?
      return on[BeginEvent].first.then((_) => broadcast(e));
    }
  }

  Future broadcastDelayed(Duration delay, Event e) {
    return new Future.delayed(delay, () => _addEvent(e));
  }

  void subscribe(String listenerName, Type actorType,
      {EventFilter filter: const AllEvents()}) {
    filter.filter(_ctrl.stream).listen((e) {
      var actor = _actors["$actorType"];
      _registry.getListener(listenerName, actorType)(e, actor, this);
    });
  }

  /// Synchronously add an event to the broadcast stream. All subscriptions will
  /// receive the event before this method is finished.
  Event _addEvent(Event e) {
    e._timeStamp = _stopwatch.elapsed;
    _ctrl.add(e);
    return e;
  }
}
