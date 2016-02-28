library august.ui;

import 'dart:async';
export 'dart:async';

/// Function which takes a map of module types to "interfaces": objects specific
/// to that module which a UI can use to interact with the current [Run].
typedef dynamic CreateUi(Map interfaces);

abstract class Ui {
  // TODO: Is their something lighter weight than full Stream API?
  Stream<Interaction> get onInteraction;
}

abstract class Interaction {
//  String get moduleName;
//  String get action;
  Future run();
  Map<String, dynamic> toJson();
}
