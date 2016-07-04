// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august;

import 'dart:async';
import 'dart:collection';

import 'package:quiver/time.dart';

export 'dart:async';
export 'package:quiver/time.dart' show Clock;

part 'src/persistence.dart';
part 'src/scope.dart';
part 'src/observable.dart';

class InteractionManager implements Sink<Interaction> {
  final _ctrl = new StreamController<Interaction>(sync: true);
  final _interactorsByModule = <String, Interactor>{};
  final Persistence _persistence;
  final Clock _clock;

  FastForwarder _ff;

  InteractionManager(
      this._clock, this._persistence, Iterable<Interactor> interactors) {
    _ff = new FastForwarder(_clock);

    interactors.forEach((interactor) {
      if (_interactorsByModule.containsKey(interactor.moduleName)) {
        throw new ArgumentError.value(
            interactors,
            "interactors",
            "List of interactors contained multiple interactors for the same "
            "module name: ${interactor.moduleName}");
      }

      _interactorsByModule[interactor.moduleName] = interactor;
    });

    _ctrl.stream.listen((interaction) {
      _persistInteraction(interaction);
      _runInteraction(interaction);
    });
  }

  Duration get currentOffset => _ff.currentOffset;

  @override
  void add(Interaction interaction) {
    _ctrl.add(interaction);
  }

  @override
  void close() {
    _ctrl.close();
  }

  void run(Function script) {
    if (_persistence.savedInteractions.isNotEmpty) {
      _ff.runFastForwardable((ff) {
        script();
        var saved = _persistence.savedInteractions;
        saved.forEach((interaction) {
          new Future.delayed(interaction.offset, () {
            _runInteraction(interaction);
          });
        });
        ff.fastForward(saved.last.offset);
      });
    } else {
      script();
    }
  }

  void _persistInteraction(Interaction interaction) {
    _persistence.saveInteraction(currentOffset, interaction.moduleName,
        interaction.name, interaction.parameters);
  }

  void _runInteraction(Interaction interaction) {
    var interactor = _interactorsByModule[interaction.moduleName];

    if (interactor == null) {
      throw new StateError("No interactor configured for module: "
          "${interaction.moduleName}. Include one when constructing an"
          "InteractionManager for this module.");
    }

    interactor.run(interaction.name, interaction.parameters);
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
