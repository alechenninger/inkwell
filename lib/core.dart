// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.core;

import 'dart:async';
import 'dart:collection';

export 'dart:async';

import 'package:quiver/time.dart';

part 'src/core/modules.dart';
part 'src/core/persistence.dart';

/// A [Block] is a function which defines the body of a [Script]. It emits
/// events, adds event listeners, and interacts with any installed [Module]s for
/// the `Script`.
typedef void Block(Run run, Map modules);

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
  Script(this.name, this.version, this.modules, this.block);
}

/// Events capture what is happening while playing. Events can be listened to
/// and they can be emitted.
class Event {
  final String alias;

  Event(this.alias);
}

start(Script script,
    {List<CreateUi> uis: const [],
    Persistence persistence: const NoopPersistance()}) {
  var clock = new Clock();
  var run;
  var scriptModules;

  if (persistence.savedEvents.isNotEmpty) {
    var ff = new _FastForwarder(clock);
    run = new Run(ff.currentPlayTime);
    scriptModules = new ScriptModules(script.modules, run, persistence);
    ff.run((ff) {
      script.block(run, scriptModules.modules);
      persistence.savedEvents.forEach((e) {
        new Future.delayed(e.offset, () {
          scriptModules.interfaceHandlers[e.moduleName]
              .handle(e.action, e.args);
        });
      });
      ff.fastForward(persistence.savedEvents.last.offset);
    });
    ff.switchToParentZone();
  } else {
    var startTime = clock.now();
    var cpt = () => clock.now().difference(startTime);
    run = new Run(cpt);
    scriptModules = new ScriptModules(script.modules, run, persistence);
    script.block(run, scriptModules.modules);
  }

  uis.forEach((createUi) => createUi(scriptModules.interfaces));
}

class Run {
  var _ctrl = new StreamController<Event>.broadcast(sync: true);
  CurrentPlayTime _currentPlayTime;

  Run(this._currentPlayTime) {
    //every((e) => true).listen((e) => print("${currentPlayTime()}: ${e.alias}"));
  }

  Future emit(Event event,
          {Duration delay: Duration.ZERO,
          Canceller canceller: const _Uncancellable()}) =>
      new Future.delayed(delay, () {
        if (canceller.cancelled) return _never;
        _ctrl.add(event);
        return event;
      });

  /// Listens to events happening in the script run. See [Once].
  Future once(String eventAlias) =>
      _ctrl.stream.firstWhere((e) => e.alias == eventAlias);

  /// Listens to events happening in the script run. See [Every].
  Stream every(bool test(Event)) => _ctrl.stream.where(test);

  Duration currentPlayTime() => _currentPlayTime();
}

class ScriptModules {
  final Map modules = {};
  final Map interfaces = {};
  final Map interfaceHandlers = {};

  ScriptModules(
      List<ModuleDefinition> moduleDefs, Run run, Persistence persistence) {
    moduleDefs.forEach((moduleDef) {
      var module = moduleDef.create(run, modules);

      _putIn(modules, module.runtimeType, module);

      if (moduleDef is HasInterface) {
        var handler = moduleDef.createInterfaceHandler(module);
        var interface = moduleDef.createInterface(module, (action, args) {
          var event = new InterfaceEvent(
              moduleDef.runtimeType, action, args, run.currentPlayTime());
          persistence.saveEvent(event);
          handler.handle(action, args);
        });

        _putIn(interfaces, module.runtimeType, interface);
        _putIn(interfaceHandlers, module.runtimeType, handler);
      }
    });
  }

  _putIn(Map map, Type type, dynamic value) {
    map[type] = value;
    map['$type'] = value;
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
