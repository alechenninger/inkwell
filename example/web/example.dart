// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:august/august.dart';
import 'package:august/options.dart';
import 'package:august/scenes.dart';
import 'package:august/dialog.dart';
import 'package:august/ui/html/html_ui.dart';

import 'dart:html';

// Instantiate modules top level for easy accessibility from script methods
final options = new Options();
final scenes = new Scenes();
final dialog = new Dialog();

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
  var interactionsMngr = new InteractionManager(clock, persistence,
      [new OptionsInteractor(options), new DialogInteractor(dialog)]);

  // Create user interface objects using interactions manager.
  var optionsUi = new OptionsUi(options, interactionsMngr);
  var dialogUi = new DialogUi(dialog, interactionsMngr);

  // Present the user interface(s) with HTML
  new SimpleHtmlUi(querySelector("#example"), optionsUi, dialogUi);

  // Finally, start the story using the interaction manager so saved
  // interactions are replayed.
  interactionsMngr.run(example);
}

example() async {
  var dragonStandoff = await scenes.reenterable().enter();
  var sword = new Sword();

  // Another strategy for "first" entrance of this scene would be a custom
  // scope that we manage via scope.exit()
  // This would be equivalent to the old dialog.clear()
  dialog.narrate("A dragon stands before you!",
      scope: dragonStandoff /*.first*/);

  // Availability limited to current scene may make sense as default
  var attack = options.newOption("Attack it!", available: dragonStandoff);
  var runAway = options.newOption("Run away!", available: dragonStandoff);

  attack.onUse.listen((o) async {
    var attacking = await scenes.oneTime().enter();

    dialog.narrate("The dragon readies its flame...", scope: attacking);

    var deflectWithSword = options
        .newOption("Deflect the fire with your sword.", available: attacking);
    var deflectWithShield = options
        .newOption("Deflect the fire with your shield.", available: attacking);
    var dash =
        options.newOption("Dash toward the dragon.", available: attacking);

    deflectWithSword.onUse.listen((_) {
      dialog.narrate("You survive, but your sword is burnt.",
          scope: attacking);
      sword.isBurnt.set((_) => true);
      dragonStandoff.enter();
    });

    deflectWithShield.onUse.listen((_) async {
      var deflected = await scenes.oneTime().enter();
      dialog.narrate("Your shield sets aflame and you suffer terrible burns.",
          scope: deflected);
    });

    dash.onUse.listen((_) async {
      var dashed = await scenes.oneTime().enter();
      dialog.narrate("You make it underneath the dragon, unharmed.",
          scope: dashed);
    });
  });

  runAway.onUse.listen((o) async {
    dragonStandoff.done();

    var runningAway = await scenes.oneTime().enter();

    dialog.narrate("Running away.", scope: runningAway);

    if (sword.isBurnt.value) {
      dialog.narrate("Your hot sword melts through its holster and tumbles "
          "behind you.", scope: runningAway);
    }

    var thisWay = dialog.add("This way!", scope: runningAway);
    var follow = thisWay.addReply("Follow the mysterious voice");
    var hide = thisWay.addReply("Hide");

    follow.onUse.listen((_) async {
      var following = await scenes.oneTime().enter();
      var player = dialog.voice(name: "Bob");
      var mysteriousVoice = dialog.voice();

      // Default scope of current scene may be nice
      player.say("What are you doing here?", scope: following);

      var toMysteryVoice = mysteriousVoice
          .say("I could ask you the same thing.", scope: following);
      var needDragonScales = toMysteryVoice.addReply("I need dragon scales");
      var sayNothing = toMysteryVoice.addReply("Say nothing.");

      needDragonScales.onUse.listen((_) {
        player.say("I need dragon scales.", scope: following);
        mysteriousVoice.say("Good luck with that.", scope: following);
      });

      sayNothing.onUse.listen((_) {});
    });
  });
}

class Sword {
  final isBurnt = new Observable<bool>.ofImmutable(false);
}
