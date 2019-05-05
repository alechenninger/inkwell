// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:august/august.dart';
import 'package:august/options.dart';
import 'package:august/scenes.dart';
import 'package:august/dialog.dart';
import 'package:august/ui/html/html_ui.dart';

import 'dart:html';

// Instantiate modules top level for easy accessibility from script methods
final options = Options();
final scenes = Scenes();
final dialog = Dialog(
    defaultScope: () => scenes.currentScene.cast<Scope>().orElse(always));

main() {
  // TODO: How will users know how to do this setup for all modules they want
  // to use? How will we give feedback when not setup correctly?
  // Probably worth trimming and refactoring this so setup is very tiny, and
  // invalid setup fails at compile time.

  // Boilerplate time tracking
  var clock = Clock();

  // Need a persistence strategy
  var persistence = NoPersistence();

  // Create interactions manager using modules, persistence, and time tracking.
  var interactionsMngr = InteractionManager(clock, persistence,
      [OptionsInteractor(options), DialogInteractor(dialog)]);

  // Create user interface objects using interactions manager.
  var optionsUi = OptionsUi(options, interactionsMngr);
  var dialogUi = DialogUi(dialog, interactionsMngr);

  // Present the user interface(s) with HTML
  SimpleHtmlUi(querySelector("#example"), optionsUi, dialogUi);

  // Finally, start the story using the interaction manager so saved
  // interactions are replayed.
  interactionsMngr.run(example);
}

example() async {
  var dragonStandoff = await scenes.reentrant().enter();
  var sword = Sword();

  // Another strategy for "first" entrance of this scene would be a custom
  // scope that we manage via scope.exit()
  // This would be equivalent to the old dialog.clear()
  dialog.narrate("A dragon stands before you!",
      scope: dragonStandoff /*.first*/);

  // Availability limited to current scene may make sense as default
  /*
  one scheme:
  have a default scope for all dialog/options/whatever as current scene.
  means there is a scope, CurrentScene.

  dialog.defaultScope(following, while: following);
  following.scope(dialog);

  what about if you need to step out of this default?
  newOption("...", available: overrideScopeHere);

  another use for default is around modality. for example, you want a reply
  which excludes options. and then you may want options which are immune to
  this. but here you probably don't want to override too easily.

  newOption("..", overrideAvailable:
                  available: default.and(dragonStandoff))
                  available: dragonStandoff, scopeOverride: true)

  also if you set default scope, is it an and with current?

  dialog.setDefaultScope((current) => current.and(following), while: following);
  dialog.setDefaultScope(dialog.defaultScope.and(following), while: following);
  dialog.setDefaultScope(following, while: following, combine: (s1,s2) => s1.and(s2));

  dialog.setDefaultScope(following, while: following);
  dialog.setDefaultScope((_) => following, while: following);

  var following = await scenes.oneTime().enter();
  var currentDefault = dialog.defaultScope;
  following.onExit.listen((_) => dialog.defaultScope = currentDefault);
  dialog.defaultScope = dialog.defaultScope.and(following);

  // or should modal stuff be it's own thing?
  mode.enter(dialog)
  if (mode.!isEntered)
  Options(mode)
  options.newOption("...", ignoreMode: true)

  options.newOption("...", available: mode)

  // What would default scope normally be?
  within current scene and allowed by current mode?

  gets into how do you define allowed by current mode?
  mode.allowed(option) -> scope

  mode.acquire(dialog) then mode.isAllowed is true for all dialog.replies

  dialog.owns(thing) => replies.contains(thing);

  // Consider modelling all user-available actions in a shared way
  // Then we have a shared place to manage when actions are available
  var action = interactions.get();
  action.onUse -> stream
  action.use -> future ?
  action.availability -> scope

  var mode = interactions.newMode();
  mode.allow(action);
  mode.enabledWhile(scope);

  var what = player.say("what's up?");

  var notMuch = what.addReply("Not much", modal: true);
  var lookOut = what.addReply("Look out!", modal: true);
  var walkAway = options.limitedUse("Walk away", mode: notMuch.mode);

  */
  var attack = options.limitedUse("Attack it!", available: dragonStandoff);
  var runAway = options.limitedUse("Run away!", available: dragonStandoff);

  attack.onUse.listen((o) async {
    var attacking = await scenes.oneTime().enter();

    dialog.narrate("The dragon readies its flame...");

    var deflectWithSword = options
        .limitedUse("Deflect the fire with your sword.", available: attacking);
    var deflectWithShield = options
        .limitedUse("Deflect the fire with your shield.", available: attacking);
    var dash =
        options.limitedUse("Dash toward the dragon.", available: attacking);

    deflectWithSword.onUse.listen((_) {
      dialog.narrate("You survive, but your sword has melted!",
          scope: dragonStandoff);
      sword.isMelted.set((_) => true);
      dragonStandoff.enter();
    });

    deflectWithShield.onUse.listen((_) async {
      await scenes.oneTime().enter();
      dialog.narrate("Your shield sets aflame and you suffer terrible burns.");
    });

    dash.onUse.listen((_) async {
      await scenes.oneTime().enter();
      dialog.narrate("You make it underneath the dragon, unharmed.");
    });
  });

  runAway.onUse.listen((o) async {
    dragonStandoff.done();

    var runningAway = await scenes.oneTime().enter();

    dialog.narrate("Running away.", scope: runningAway);

    if (sword.isMelted()) {
      dialog.narrate(
          "Your hot sword burns through its holster and tumbles behind you.",
          scope: runningAway);
    }

    var thisWay = dialog.add("This way!", scope: runningAway);
    var follow = thisWay.addReply("Follow the mysterious voice");
    var hide = thisWay.addReply("Hide");

    follow.onUse.listen((_) async {
      var following = await scenes.oneTime().enter();
      var player = dialog.voice(name: "Bob");
      var mysteriousVoice = dialog.voice();

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

// Consider something fancy for state tracking / modeling transactions more
// explicitly.
class Sword {
  final isMelted = Observable<bool>.ofImmutable(false);
}
