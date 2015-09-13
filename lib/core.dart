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
  var scriptModules;

  if (persistence.savedEvents.isNotEmpty) {
    var ff = new _FastForwarder(clock);
    run = new Run(ff.getCurrentPlayTime);
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

class Run {
  StreamController<Event> _ctrl =
      new StreamController<Event>.broadcast(sync: true);
  GetCurrentPlayTime _currentPlayTime;

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
  Future once(dynamic eventAliasOrTest) {
    if (eventAliasOrTest is! String && eventAliasOrTest is! EventTest) {
      throw new ArgumentError.value(eventAliasOrTest, "eventAliasOrTest",
          "Must be a String or EventTest, was ${eventAliasOrTest.runtimeType}");
    }

    var test = eventAliasOrTest is String
        ? (Event e) => e.name == eventAliasOrTest
        : eventAliasOrTest;

    return _ctrl.stream.firstWhere(test);
  }

  /// Listens to events happening in the script run. See [Every].
  Stream every(bool test(Event)) => _ctrl.stream.where(test);

  Duration currentPlayTime() => _currentPlayTime();
}

/// Adds an [Event] listener for the next (and only the next) event that matches
/// the [eventAliasOrTest]. This may be a String or an [EventTest]. If a String
/// is passed, this is equivalent to passing the `EventTest` function,
/// `(e) => e.alias == eventAliasOrTest`.
typedef Future<Event> Once(dynamic eventAliasOrTest);

typedef Stream<Event> Every(EventTest eventTest);

/// Emits an [Event] with an optional [delay]. Returns a [Future] which
/// completes when the event has been emitted and all listeners have received
/// it. Optionally pass a [Canceller] to later cancel an event from being
/// emitted, if it has not already been.
typedef Future<Event> Emit(Event event, {Duration delay, Canceller canceller});

typedef bool EventTest(Event event);

/// Events capture what is happening while playing. Events can be listened to
/// and they can be emitted.
class Event {
  final String name;

  Event(this.name);
}

/// Returns the current play time, which is a [Duration] since the beginning of
/// the first [Run]. Note that the amount of time lapsed is saved, so starting
/// a saved run does not reset the play time to zero, it picks up where it left
/// off.
typedef Duration GetCurrentPlayTime();

/// Instantiates modules for a particular run and houses them.
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
