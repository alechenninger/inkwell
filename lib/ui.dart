library august.ui;

import 'package:august/august.dart' show Module;

import 'dart:async';
export 'dart:async';

abstract class UiModule implements Module {
  Ui get ui;
  InteractionDeserializer get interactionDeserializer;
}

abstract class Ui {
  // TODO: Is their something lighter weight than full Stream API?
  Stream<Interaction> get onInteraction;
}

abstract class Interaction {
  Future run();
  Map<String, dynamic> toJson();
}

abstract class InteractionDeserializer {
  Interaction deserializeInteraction(String type, Map<String, dynamic> json);
}
