part of august;

/// Factory for module and optional additional related objects (see
/// [InterfaceModuleDefinition]).
///
/// A module is used to provide higher level, reusable functionality to a
/// [Block].
abstract class ModuleDefinition<T> {
  T createModule(Run run, Map modules);
}

/// Expands on [ModuleDefinition] for a module which may be interacted with from
/// a user interface.
abstract class InterfaceModuleDefinition<T> extends ModuleDefinition<T> {
  Interface createInterface(T module, InterfaceEmit emit);

  InterfaceHandler createInterfaceHandler(T module);
}

/// Emits events from user interactions. These events will be serialized, so
/// [args] should be natively serializable with [JSON].
typedef void InterfaceEmit(String action, Map<String, dynamic> args);

/// Translates the serializable actions of a player to methods of a module.
abstract class InterfaceHandler {
  void handle(String action, Map<String, dynamic> args);
}

/// A marker interface for types which provide an API to a `Ui` to interact with
/// modules.
///
/// A user's interaction with a game needs to be serialized so it may be played
/// back at a later time. Otherwise, a player would not be able to save their
/// progress for later. An `Interface` uses an [InterfaceEmit] to interact with
/// the interface's module with serializable primitives. An [InterfaceHandler]
/// bridges these serializable player actions with the underlying module
/// implementation.
abstract class Interface {}

class NoopInterfaceHandler implements InterfaceHandler {
  void handle(action, args) {}
}

/*
We need an interface for scripts to use
we need an interface for ui to use
the impl for ui must record actions
something needs to be able to play back those actions
both interfaces are backed by the same state

 */
