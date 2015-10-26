/// A library which exports some standard, default modules.
library august.modules;

import 'package:august/core.dart';

part 'src/modules/options.dart';
part 'src/modules/dialog.dart';

/// Use when the interface has no actions available to the player; it is read
/// only basically.
class NoopInterfaceHandler implements InterfaceHandler {
  void handle(action, args) {}
}
