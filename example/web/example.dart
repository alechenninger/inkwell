// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.example;

import 'package:august/august.dart';
import 'package:august/options.dart';
import 'package:august/scenes.dart';
import 'package:august/ui/html/html_ui.dart';

import 'dart:html';

// Instantiate modules top level for easy accessibility from script methods
final options = new Options();
final scenes = new Scenes();

main() {
  // TODO: How will users know how to do this setup for all modules they want
  // to use? How will we give feedback when not setup correctly?
  // Probably worth trimming and refactoring this so setup is very tiny, and
  // invalid setup fails at compile time.

  // Boilerplate time tracking
  var clock = new Clock();

  // Need a persistence strategy
  var persistence = new NoPersistence();

  // Create interactions manager using modules, persistence, and time tracking.
  var interactionsMngr = new InteractionManager(
      clock, persistence, [new OptionsInteractor(options)]);

  // Create user interface objects using interactions manager.
  var optionsUi = new OptionsUi(options, interactionsMngr);

  new SimpleHtmlUi(querySelector("#example"), optionsUi);
  interactionsMngr.run(example);
}

example() async {
  var dragonStandoff = await scenes.reenterable().enter();
  var sword = new Sword();

  print("A dragon stands before you!");

  // Availability limited to current scene may make sense as default
  var attack = options.newOption("Attack it!", available: dragonStandoff);
  var runAway = options.newOption("Run away!", available: dragonStandoff);

  attack.onUse.listen((o) async {
    var attacking = await scenes.oneTime().enter();

    print("The dragon readies its flame...");

    var deflectWithSword = options
        .newOption("Deflect the fire with your sword.", available: attacking);
    var deflectWithShield = options
        .newOption("Deflect the fire with your shield.", available: attacking);
    var dash =
        options.newOption("Dash toward the dragon.", available: attacking);

    deflectWithSword.onUse.listen((_) {
      print("You survive, but your sword is burnt.");
      sword.isBurnt.set((_) => true);
      dragonStandoff.enter();
    });

    deflectWithShield.onUse.listen((_) {
      print("Your shield sets aflame and you suffer terrible burns.");
      scenes.oneTime().enter();
    });

    dash.onUse.listen((_) {
      print("You make it underneath the dragon, unharmed.");
      scenes.oneTime().enter();
    });
  });

  runAway.onUse.listen((o) async {
    dragonStandoff.done();

    await scenes.oneTime(title: "Running away").enter();

    print("Running away.");

    if (sword.isBurnt.value) {
      print("Your hot sword melts through its holster and tumbles behind you.");
    }
  });
}

class Sword {
  final isBurnt = new Observable<bool>.ofImmutable(false);
}
