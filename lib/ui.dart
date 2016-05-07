library august.ui;

import 'package:august/august.dart';

import 'dart:async';
export 'dart:async';

typedef Duration CurrentOffset();

class InteractionManager implements Sink<Interaction> {
  final _ctrl = new StreamController<Interaction>(sync: true);
  final _interactorsByModule = <String, Interactor>{};
  final Persistence _persistence;
  final CurrentOffset _currentOffset;

  InteractionManager(this._currentOffset, this._persistence,
      Iterable<Interactor> interactors) {
    interactors.forEach((interactor) {
      _interactorsByModule[interactor.moduleName] = interactor;
    });

    _ctrl.stream.listen((interaction) {
      _persistInteraction(interaction);
      _runInteraction(interaction);
    });
  }

  void _persistInteraction(Interaction interaction) {
    _persistence.saveInteraction(_currentOffset(), interaction.moduleName,
        interaction.name, interaction.parameters);
  }

  void _runInteraction(Interaction interaction) {
    var interactor = _interactorsByModule[interaction.moduleName];
    interactor.run(interaction.name, interaction.parameters);
  }

  @override
  void add(Interaction interaction) {
    _ctrl.add(interaction);
  }

  @override
  void close() {
    _ctrl.close();
  }
}

abstract class Interaction {
  String get moduleName;
  String get name;
  Map<String, dynamic> get parameters;
}

abstract class Interactor {
  /// The name of the module this interactor supports.
  String get moduleName;
  void run(String action, Map<String, dynamic> parameters);
}
