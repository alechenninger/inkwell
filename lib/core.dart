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

typedef Stream<Event> Every(bool test(Event));

/// Emits an [Event] with an optional [delay]. Returns a [Future] which
/// completes when the event has been emitted and all listeners have received
/// it.
typedef Future<Event> Emit(Event event, {Duration delay});

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
  var _ctrl = new StreamController<Event>.broadcast(sync: true);

  Future emit(event, {delay: Duration.ZERO}) =>
      // Add the new event in a Future because we can't / don't want to
      // broadcast in the middle of a callback.
      new Future.delayed(delay, () {
    _ctrl.add(event);
    return event;
  });

  Future once(String eventAlias) {
    return _ctrl.stream.firstWhere((e) => e.alias == eventAlias);
  }

  Stream every(bool test(Event)) => _ctrl.stream.where(test);

  Map interfaces = {};
  Map modules = script.modules.fold({}, (map, moduleDef) {
    var module = moduleDef.create(once, every, emit, map);
    map[module.runtimeType] = module;

    if (module is HasInterface) {
      var iHandler = module.createInterfaceHandler(module);
      interfaces[module.runtimeType] = module.createInterface(module,
          (action, args) {
        // TODO: should also persist for keeping track of progress
        iHandler.handle(action, args);
      });
    }
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

class OptionsModule implements ModuleDefinition, HasInterface {
  Options create(Once once, Every every, Emit emit, Map modules) {
    return new Options(emit);
  }

  OptionsInterface createInterface(Options options, InterfaceEmit emit) {
    return new OptionsInterface(options, emit);
  }

  OptionsInterfaceHandler createInterfaceHandler(Options options) {
    return new OptionsInterfaceHandler(options);
  }
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
}

class OptionsInterface {
  final Options _options;
  final InterfaceEmit _emit;

  OptionsInterface(this._options, this._emit);

  void use(String option) {
    // UserEmit created per module so scope is restricted by default
    _emit("use", {"option": option});
  }

  Set<String> get available => _options.available;
}

class OptionsInterfaceHandler implements InterfaceHandler {
  final Options _options;

  OptionsInterfaceHandler(this._options);

  void handle(String action, Map args) {
    switch (action) {
      case "use":
        _options.use(args["option"]);
    }
  }
}
