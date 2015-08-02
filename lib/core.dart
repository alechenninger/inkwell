// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.core;

import 'dart:async';
export 'dart:async';

/// A [Block] is a function which defines the body of a [Script]. It emits
/// events, adds event listeners, and adds to the [Options] available to the
/// player.
typedef void Block(Once once, Options options, Emit emit);

/// Adds an [Event] listener for the next (and only the next) event that occurs
/// with the [eventAlias].
typedef Future<Event> Once(String eventAlias);

/// Emits an [Event] with an optional [delay]. Returns a [Future] which
/// completes when the event has been emitted and all listeners have received
/// it.
typedef Future<Event> Emit(Event event, {Duration delay});

/// Combines many [Blocks] into one which consolidates all passed blocks,
/// applything them in iteration order.
Block blocks(List<Block> blocks) => (Once once, Options options, Emit emit) {
  blocks.forEach((p) => p(once, options, emit));
};

class Script {
  final String name;
  final String version;

  /// See [Block]
  final Block block;

  Script(this.name, this.version, this.block);
}

class Event {
  final String alias;

  Event(this.alias);
}

start(Script script) {
  StreamController<Event> _ctrl = new StreamController.broadcast(sync: true);

  Future<Event> emit(event, {Duration delay: Duration.ZERO}) =>
      // Add the new event in a Future because we can't / don't want to
      // broadcast in the middle of a callback.
      new Future.delayed(delay, () {
    _ctrl.add(event);
    return event;
  });

  Future<Event> once(String eventAlias) {
    return _ctrl.stream.firstWhere((e) => e.alias == eventAlias);
  }

  script.block(once, new Options(emit), emit);
}

class Options {
  final Set _opts = new Set();
  final List<Set> _exclusives = new List();
  final Emit _emit;

  Options(this._emit);

  bool add(String option) => _opts.add(option);

  /// Adds all of the options, and binds them together such that the use of any
  /// of them, removes the rest. That is, they are mutually exclusive options.
  void addExclusive(Iterable<String> options) {
    var asSet = options.toSet();
    asSet.forEach(add);
    _exclusives.add(asSet);
  }

  bool remove(String option) => _opts.remove(option);

  /// Emits an [Event] with the [option] as its alias and removes it from the
  /// list of available options. Other mutually exclusive options are removed as
  /// well.
  ///
  /// Throws an [ArgumentError] if the `option` is not available.
  // TODO: Should this actually emit an event? Should this event be saved to
  // disk? No I think because non-user interactions could stil call this API.
  void use(String option) {
    if (!_opts.remove(option)) {
      throw new ArgumentError.value(
          option, "option", "Option not available to be used.");
    }

    _exclusives.where((s) => s.contains(option)).forEach((s) {
      s.forEach((o) {
        _opts.remove(o);
      });
      _exclusives.remove(s);
    });

    _emit(new Event(option));
  }

  Set<String> get available => new Set.from(_opts);

  noSuchMethod(Invocation invocation) {
    invocation.memberName
  }
}
