import 'package:august/august.dart';

import 'src/core.dart';

export 'src/persistence.dart' hide FastForwarder;

abstract class UserInterface {
  Stream<MetaAction> get metaActions;
  Stream<Action> get actions;
  void play(Stream<Event> events);
}
