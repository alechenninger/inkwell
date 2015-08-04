// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.core;

import 'dart:async';
export 'dart:async';

/// A [Block] is a function which defines the body of a [Script]. It emits
/// events, adds event listeners, and adds to the [Options] available to the
/// player.
typedef void Block(Once once, Emit emit, Map modules);

/// Adds an [Event] listener for the next (and only the next) event that occurs
/// with the [eventAlias].
typedef Future<Event> Once(String eventAlias);

typedef Stream<Event> Every(bool test(Event event));

/// Emits an [Event] with an optional [delay]. Returns a [Future] which
/// completes when the event has been emitted and all listeners have received
/// it. Optionally pass a [canceller] to later cancel an event from being
/// emitted.
typedef Future<Event> Emit(Event event, {Duration delay, Canceller canceller});

class Script {
  final String name;
  final String version;

  /// See [Block]
  final Block block;

  final List<ModuleDefinition> modules;

  Script(
      this.name, this.version, List<ModuleDefinition> this.modules, this.block);
}

class Event {
  final String alias;

  Event(this.alias);
}

start(Script script, List<CreateUi> uis) {
  var ctrl = new StreamController<Event>.broadcast(sync: true);

  Future emit(event, {delay: Duration.ZERO, Canceller canceller: const _Uncancellable()}) {
    return new Future.delayed(delay, () {
      if (canceller.cancelled) {
        return _never;
      }

      ctrl.add(event);
      return event;
    });
  }

  Future once(String eventAlias) {
    return ctrl.stream.firstWhere((e) => e.alias == eventAlias);
  }

  Stream every(bool test(Event)) => ctrl.stream.where(test);

  Map interfaces = {};
  Map modules = script.modules.fold({}, (map, moduleDef) {
    var module = moduleDef.create(once, every, emit, map);
    map[module.runtimeType] = module;

    if (moduleDef is HasInterface) {
      var iHandler = moduleDef.createInterfaceHandler(module);
      interfaces[module.runtimeType] = moduleDef.createInterface(module,
          (action, args) {
        // TODO: should also persist for keeping track of progress
        iHandler.handle(action, args);
      });
    }

    return map;
  });

  uis.forEach((createUi) => createUi(interfaces));

  script.block(once, emit, modules);
}

abstract class InterfaceHandler {
  void handle(String action, Map<String, dynamic> args);
}

/// Emits events from user interactions. These events will be serialized, so
/// [args] should be natively serializable with [JSON].
typedef void InterfaceEmit(String action, Map<String, dynamic> args);

abstract class ModuleDefinition {
  /// Module tracks state, emits events, allows listening to those events.
  dynamic create(Once once, Every every, Emit emit, Map modules);
}

abstract class HasInterface {
  /// Provides access to state and actions of the module. Actions should emit
  /// events which must be handled by the module's [InterfaceHandler].
  /// Swappable.
  dynamic createInterface(dynamic module, InterfaceEmit emit);

  /// Handles events emitted in interface.
  InterfaceHandler createInterfaceHandler(dynamic module);
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
