// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.core;

import 'dart:async';
import 'dart:collection';

export 'dart:async';

import 'package:quiver/iterables.dart';
import 'package:quiver/time.dart';

part 'src/core/modules.dart';
part 'src/core/persistence.dart';

/// A [Block] is a function which defines the body of a [Script]. It emits
/// events, adds event listeners, and interacts with any installed [Module]s for
/// the `Script`.
typedef void Block(Once once, Emit emit, Map modules);

/// Adds an [Event] listener for the next (and only the next) event that occurs
/// with the [eventAlias].
typedef Future<Event> Once(String eventAlias);

typedef Stream<Event> Every(bool test(Event event));

/// Emits an [Event] with an optional [delay]. Returns a [Future] which
/// completes when the event has been emitted and all listeners have received
/// it. Optionally pass a [Canceller] to later cancel an event from being
/// emitted, if it has not already been.
typedef Future<Event> Emit(Event event, {Duration delay, Canceller canceller});

typedef Duration CurrentPlayTime();

class Script {
  final String name;
  final String version;

  /// See [Block]
  final Block block;

  final List<ModuleDefinition> modules;

  /// The [name] and [version] of the script are import for loading previous
  /// progress and ensuring compatibility.
  ///
  /// The [List] of [ModuleDefinition]s defines what modules will be injected
  /// into the [block]. Modules add functionality to scripts, and may expose
  /// similar functionality to a UI layer.
  Script(
      this.name, this.version, List<ModuleDefinition> this.modules, this.block);
}

/// Events capture what is happening while playing. Events can be listened to
/// and they can be emitted.
class Event {
  final String alias;

  Event(this.alias);
}

start(Script script, {List<CreateUi> uis: const [], Persistence persistence}) {
  var ctrl = new StreamController<Event>.broadcast(sync: true);
  var clock = new Clock();

  run(CurrentPlayTime currentPlayTime) {
    Future emit(event,
            {delay: Duration.ZERO,
            Canceller canceller: const _Uncancellable()}) =>
        new Future.delayed(delay, () {
          if (canceller.cancelled) return _never;
          ctrl.add(event);
          return event;
        });

    Future once(String eventAlias) =>
        ctrl.stream.firstWhere((e) => e.alias == eventAlias);

    Stream every(bool test(Event)) => ctrl.stream.where(test);

    var interfaces = {};
    var interfaceHandlers = {};
    var modules = script.modules.fold({}, (map, moduleDef) {
      var module = moduleDef.create(once, every, emit, map);
      map[module.runtimeType] = module;

      if (moduleDef is HasInterface) {
        // TODO: need to use string for module ref everywhere instead of type
        var moduleName = module.runtimeType.toString();

        var iHandler = moduleDef.createInterfaceHandler(module);
        interfaceHandlers[moduleName] = iHandler;

        interfaces[module.runtimeType] = moduleDef.createInterface(module,
            (action, args) {
          persistence.saveEvent(new InterfaceEvent(moduleName, action, args,
              currentPlayTime()));
          iHandler.handle(action, args);
        });
      }

      return map;
    });

    // TODO: Manage UI lifecycle WRT replaying saved events?
    uis.forEach((createUi) => createUi(interfaces));

    every((e) => true).listen((e) => print("${currentPlayTime()}: ${e.alias}"));

    script.block(once, emit, modules);

    persistence.savedEvents.forEach((e) {
      new Future.delayed(e.offset, () {
        interfaceHandlers[e.moduleName].handle(e.action, e.args);
      });
    });
  }

  if (persistence.savedEvents.isNotEmpty) {
    fastForward(run, clock, persistence.savedEvents.last.offset);
  } else {
    var startTime = clock.now();
    run(() => clock.now().difference(startTime));
  }
}

typedef dynamic CreateUi(Map interfaces);

class Canceller {
  bool cancelled = false;
}

class _Uncancellable implements Canceller {
  bool get cancelled => false;
  void set cancelled(_) {
    throw new UnsupportedError("");
  }

  const _Uncancellable();
}

/// Future which will never complete.
final Future _never = new Completer().future;
