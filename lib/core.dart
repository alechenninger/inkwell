// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.core;

import 'dart:async';
import 'dart:collection';

export 'dart:async';

import 'package:quiver/time.dart';

part 'src/core/modules.dart';
part 'src/core/persistence.dart';

/// Creates a new [Run] for this script by instantiating the modules it
/// requires, replaying back any saved events provided in [persistence], and
/// creating and attaching the provided [uis]. Then, calls into that script's
/// [Block].
start(Script script,
    {List<CreateUi> uis: const [],
    Persistence persistence: const NoopPersistance()}) {
  var clock = new Clock();
  var run;
  var runModules;

  if (persistence.savedEvents.isNotEmpty) {
    var ff = new _FastForwarder(clock);

    run = new Run._(ff.getCurrentPlayTime);
    runModules = new RunModules(script.modules, run, persistence);

    ff.run((ff) {
      script.block(run, runModules.modules);
      persistence.savedEvents.forEach((e) {
        new Future.delayed(e.offset, () {
          runModules.interfaceHandlers[e.moduleName]
              .handle(e.action, e.args);
        });
      });
      ff.fastForward(persistence.savedEvents.last.offset);
    });

    ff.switchToParentZone();
  } else {
    var startTime = clock.now();
    var cpt = () => clock.now().difference(startTime);

    run = new Run._(cpt);
    runModules = new RunModules(script.modules, run, persistence);

    script.block(run, runModules.modules);
  }

  uis.forEach((createUi) => createUi(runModules.interfaces));
}

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
  Script(this.name, this.version, this.modules, this.block);
}

/// A [Block] is a function which defines the body of a [Script] by interacting
/// with that script's [Run] and installed [Module]s.
///
/// In simple terms, it's where you put your story.
///
/// N.b. there's nothing stopping you from organizing your story into multiple
/// `Block`s. Define separate block functions and call them, passing in the
/// `Run` and module map from the parent block.
typedef void Block(Run run, Map modules);

/// Function which takes a map of module types to "interfaces": objects specific
/// to that module which a UI can use to interact with the current [Run].
typedef dynamic CreateUi(Map interfaces);

/// A [Run] encapsulates the state of a currently _actively_ running script.
/// Current saved progress of a player's playthrough is not encapsulated in a
/// `Run`. This state is managed elsewhere.
///
/// A `Run`'s focus is on managing events emitted and subscribed to from
/// `Module`s and the consuming [Script]. See the [start] function.
class Run {
  Mode _mode = const Free();

  final StreamController<dynamic> _ctrl =
      new StreamController<dynamic>.broadcast(sync: true);

  final GetCurrentPlayTime _currentPlayTime;

  Mode get currentMode => _mode;

  Run._(this._currentPlayTime, {verbose: true}) {
    if (verbose) {
      every((e) => true).listen((e) => print("${currentPlayTime()}: ${e}"));
    }
  }

  Future emit(dynamic event,
      {Duration delay: Duration.ZERO,
      Canceller canceller: const _Uncancellable()}) {
    event = event is String ? new NamedEvent(event) : event;

    return new Future.delayed(delay, () {
      if (canceller.cancelled) return _never;
      _ctrl.add(event);
      return event;
    });
  }

  /// Listens to events happening in the script run. See [Once].
  Future once(dynamic eventNameOrTest) {
    if (eventNameOrTest is! String && eventNameOrTest is! EventTest) {
      throw new ArgumentError.value(eventNameOrTest, "eventAliasOrTest",
          "Must be a String or EventTest, was ${eventNameOrTest.runtimeType}");
    }

    var test = eventNameOrTest is String
        ? (e) => e is NamedEvent && e.name == eventNameOrTest
        : eventNameOrTest;

    return _ctrl.stream.firstWhere(test);
  }

  /// Listens to events happening in the script run. See [Every].
  Stream every(bool test(event)) => _ctrl.stream.where(test);

  Duration currentPlayTime() => _currentPlayTime();

  void changeMode(dynamic requestingModule, Mode to) {
    if (_mode.canChangeMode(requestingModule, to)) {
      _mode = _mode.getNewMode(to);
      return;
    }

    throw new StateError("Current mode is not allowing mode change. "
        "Current mode is $_mode. Module requesting change is "
        "${requestingModule.runtimeType}. It is requesting a change to $to.");
  }
}

/// Adds an event listener for the next (and only the next) event that matches
/// the [eventNameOrTest]. This may be a String or an [EventTest]. If a String
/// is passed, this is equivalent to passing the `EventTest` function,
/// `(e) => e is NamedEvent && e.alias == eventNameOrTest`.
typedef Future<dynamic> Once(dynamic eventNameOrTest);

typedef Stream<dynamic> Every(EventTest eventTest);

/// Emits an event object with an optional [delay]. Returns a [Future] which
/// completes when the event has been emitted and all listeners have received
/// it. Optionally pass a [Canceller] to later cancel an event from being
/// emitted, if it has not already been.
typedef Future<dynamic> Emit(dynamic event,
    {Duration delay, Canceller canceller});

typedef bool EventTest(dynamic event);

/// Special kind of event which is identified by its [name] only. [Run.emit] and
/// [Run.once] have terse syntax for [NamedEvent]s: it assumes a [String] in
/// place of an [Event] is a [NamedEvent].
class NamedEvent {
  final String name;

  NamedEvent(this.name);

  toString() => name;
}

/// Returns the current play time, which is a [Duration] since the beginning of
/// the first [Run]. Note that the amount of time lapsed is saved, so starting
/// a saved run does not reset the play time to zero, it picks up where it left
/// off.
typedef Duration GetCurrentPlayTime();

/// Instantiates modules for a particular run and houses them.
class RunModules {
  final Map modules = {};
  final Map interfaces = {};
  final Map interfaceHandlers = {};

  RunModules(List<ModuleDefinition> defs, Run run, Persistence persistence) {
    defs.forEach((moduleDef) {
      // TODO: How will module dependencies play out?
      // If modules can lazily lookup their deps, that can work
      // Otherwise need to understand dep graph which is kind of gnarly.
      // Potential cyclic dependencies and such.
      var module = moduleDef.createModule(run, modules);

      _putModule(module);

      if (moduleDef is HasInterface) {
        _initializeModuleWithInterface(moduleDef, module, run, persistence);
      }
    });
  }

  _initializeModuleWithInterface(HasInterface hasInterface, dynamic module,
      Run run, Persistence persistence) {
    var moduleType = module.runtimeType;

    var handler = hasInterface.createInterfaceHandler(module);
    var interface = hasInterface.createInterface(module, (action, args) {
      var currentPlayTime = run.currentPlayTime();
      var event = new InterfaceEvent(moduleType, action, args, currentPlayTime);

      persistence.saveEvent(event);

      run._mode.handleInterfaceEvent(action, args, handler);
    });

    _putInterface(module.runtimeType, interface);
    _putInterfaceHandler(module.runtimeType, handler);
  }

  _putModule(dynamic module) {
    modules[module.runtimeType] = module;
    modules['${module.runtimeType}'] = module;
  }

  _putInterface(Type moduleType, dynamic interface) {
    interfaces[moduleType] = interface;
    interfaces['$moduleType'] = interface;
  }

  _putInterfaceHandler(Type moduleType, InterfaceHandler handler) {
    interfaceHandlers[moduleType] = handler;
    interfaceHandlers['$moduleType'] = handler;
  }
}

/// User interaction through an interface is governed by the current [Mode] of
/// the [Run]. The default `mode` is [Free].
abstract class Mode {
  bool canChangeMode(dynamic module, Mode to);
  Mode getNewMode(Mode to);
  void handleInterfaceEvent(
      String action, Map<String, dynamic> args, InterfaceHandler handler);
}

/// A [Mode] which may freely by changed, does not augment the mode being
/// changed to, and passes all interface events through to their normal
/// [InterfaceHandler]s.
class Free implements Mode {
  const Free();

  bool canChangeMode(module, Mode to) => true;

  Mode getNewMode(Mode to) => to;

  void handleInterfaceEvent(
      String action, Map<String, dynamic> args, InterfaceHandler handler) {
    handler.handle(action, args);
  }
}

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
