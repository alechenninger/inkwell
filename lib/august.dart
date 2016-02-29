// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august;

import 'dart:async';
import 'dart:collection';

import 'package:august/ui.dart';
import 'package:quiver/time.dart';

export 'dart:async';

part 'src/modules.dart';
part 'src/persistence.dart';
part 'src/scope.dart';
part 'src/observable.dart';

/// Creates a new [Run] for this script by instantiating the modules it
/// requires, then calls the script's [Block], and replays back any saved events
/// provided in [persistence]. Finally, we create the provided [ui]s.
start(Script script,
    {List<CreateUi> uis: const [],
    Persistence persistence: const NoopPersistance()}) {
  var clock = new Clock();
  var run;
  var runModules;

  if (persistence.savedEvents.isNotEmpty) {
    var ff = new _FastForwarder(clock);

    run = new Run(ff.getCurrentPlayTime);
    runModules = new RunModules(script.modules, run, persistence);

    uis.forEach((createUi) => createUi(runModules.interfaces));

    ff.run((ff) {
      script.block(run, runModules.modules);
      persistence.savedEvents.forEach((e) {
        new Future.delayed(e.offset, () {
          runModules.interfaceHandlers[e.moduleName].handle(e.action, e.args);
        });
      });
      ff.fastForward(persistence.savedEvents.last.offset);
    });

    ff.switchToParentZone();
  } else {
    var startTime = clock.now();
    var cpt = () => clock.now().difference(startTime);

    run = new Run(cpt);
    runModules = new RunModules(script.modules, run, persistence);

    uis.forEach((createUi) => createUi(runModules.interfaces));

    script.block(run, runModules.modules);
  }
}

class Script {
  final String name;
  final String version;

  /// See [Block]
  final Block block;

  final List<Module> modules;

  /// The [name] and [version] of the script are import for loading previous
  /// progress and ensuring compatibility.
  ///
  /// The [List] of [Module]s defines what modules will be injected
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

// TODO: Is this needed anymore?
class Run {
  final GetCurrentPlayTime _currentPlayTime;

  Run(this._currentPlayTime, {verbose: false});

  Duration currentPlayTime() => _currentPlayTime();
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
    for (var def in defs) {
      // TODO: How will module dependencies play out?
      // If modules can lazily lookup their deps, that can work
      // Otherwise need to understand dep graph which is kind of gnarly.
      // Potential cyclic dependencies and such.
      var module = def.createModule(run, modules);

      _putModule(module);

      if (def is InterfaceModuleDefinition) {
        _initializeInterface(def, module, run, persistence);
      }
    }
  }

  _initializeInterface(InterfaceModuleDefinition moduleDef, dynamic module,
      Run run, Persistence persistence) {
    var moduleType = module.runtimeType;

    var handler = moduleDef.createInterfaceHandler(module);
    var interface = moduleDef.createInterface(module, (action, args) {
      var currentPlayTime = run.currentPlayTime();
      var event = new InterfaceEvent(moduleType, action, args, currentPlayTime);

      persistence.saveEvent(event);

      handler.handle(action, args);
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
