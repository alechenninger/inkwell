part of august.core;

abstract class ModuleDefinition {
  /// A module tracks state, emits events, allows listening to those events.
  dynamic create(Run run, Map modules);
}

/// If implemented by a [ModuleDefinition], indicates this module can be
/// interacted with by a user interface.
abstract class HasInterface {
  /// Provides access to state and actions of the module. Actions should emit
  /// events which must be handled by the module's [InterfaceHandler]. Interface
  /// events are special because they need to be serializable and deserializable
  /// so a playthrough can be recreated at a later time. If a UI just used a
  /// module directly, there would be no separation between changes which were
  /// caused by a player, and changes which were caused by the logic of the
  /// [Script]'s [Block].
  dynamic createInterface(dynamic module, InterfaceEmit emit);

  /// Handles events emitted in interface.
  InterfaceHandler createInterfaceHandler(dynamic module);
}

/// Emits events from user interactions. These events will be serialized, so
/// [args] should be natively serializable with [JSON].
typedef void InterfaceEmit(String action, Map<String, dynamic> args);

/// Translates the serializable actions of a player to methods of a module.
abstract class InterfaceHandler {
  void handle(String action, Map<String, dynamic> args);
}
