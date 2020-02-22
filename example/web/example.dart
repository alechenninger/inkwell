// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:august/august.dart';
import 'package:august/options.dart';
import 'package:august/scenes.dart';
import 'package:august/dialog.dart';
import 'package:august/prompts.dart';
import 'package:august/ui/html/html_persistence.dart';
import 'package:august/ui/html/html_ui.dart';

import 'dart:html';

import 'package:pedantic/pedantic.dart';

// Instantiate modules top level for easy accessibility from script methods
final story = Story();
final scenes = Scenes();
final options = Options(
    defaultScope: () => scenes.currentScene.cast<Scope>().orElse(always));
final dialog = Dialog(story,
    defaultScope: () => scenes.currentScene.cast<Scope>().orElse(always));
final prompts = Prompts();

void main() {
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
  var promptsUi = PromptsUi(prompts, interactionsMngr);

  // Present the user interface(s) with HTML
  SimpleHtmlUi(querySelector('#example'), optionsUi, dialogUi, promptsUi);

  // Finally, start the story using the interaction manager so saved
  // interactions are replayed.
  interactionsMngr.run(example);
}

void example() async {
  dragonStandoff();
}

void dragonStandoff() async {
  var dragonStandoff = await scenes.reentrant().enter();
  var sword = Sword();

  dialog.narrate('A dragon stands before you!');

  var attack = options.oneTime('Attack it!');
  var runAway = options.oneTime('Run away!');

  attack.onUse.listen((_) {
    attackDragon(dragonStandoff, sword);
  });

  runAway.onUse.listen((_) async {
    dragonStandoff.done();
    runAwayFromDragon(sword);
  });
}

void attackDragon(Scene dragonStandoff, Sword sword) async {
  await scenes.oneTime().enter();

  dialog.narrate('The dragon readies its flame...');

  var deflectWithSword = options.oneTime('Deflect the fire with your sword.');
  var deflectWithShield = options.oneTime('Deflect the fire with your shield.');
  var dash = options.oneTime('Dash toward the dragon.');

  deflectWithSword.onUse.listen((_) async {
    dialog.narrate('You survive, but your sword has melted!',
        scope: dragonStandoff);
    sword.isMelted.value = true;
    await dragonStandoff.enter();
  });

  deflectWithShield.onUse.listen((_) async {
    await scenes.oneTime().enter();
    dialog.narrate('Your shield sets aflame and you suffer terrible burns.');
  });

  dash.onUse.listen((_) async {
    await scenes.oneTime().enter();
    dialog.narrate('You make it underneath the dragon, unharmed.');
  });
}

void runAwayFromDragon(Sword sword) async {
  var runningAway = await scenes.oneTime().enter();

  dialog.narrate('Running away.');

  if (sword.isMelted()) {
    dialog.narrate(
        'Your hot sword burns through its holster and tumbles behind you.');
  }

  var thisWay = dialog.add('This way!');

//    var follow = options.exclusive('Follow the mysterious voice');
//    var hide = follow.exclusiveWith('Hide');
//    hide.exclusiveWith('')

  var follow = thisWay.addReply('Follow the mysterious voice');
  var hide = thisWay.addReply('Hide');

  follow.onUse.listen((_) async {
    var following = await scenes.oneTime().enter();
    var player = dialog.voice(name: 'Bob');
    var mysteriousVoice = dialog.voice(name: '(mysterious voice)');

    player.say('What are you doing here?');

    var toMysteryVoice = mysteriousVoice.say('I could ask you the same thing.');
    var needDragonScales = toMysteryVoice.addReply('I need dragon scales');
    var sayNothing = toMysteryVoice.addReply('Say nothing.');

    needDragonScales.onUse.listen((_) {
      player.say('I need dragon scales.');
      mysteriousVoice.say('Good luck with that.');
    });

    sayNothing.onUse.listen((_) {});
  });
}

class Player {
  Voice _voice;

  Player(Dialog dialog) {
    _voice = dialog.voice(name: '(unknown hero)');
  }
}

// Consider something fancy for state tracking / modeling transactions more
// explicitly.
class Sword {
  final isMelted = Observable<bool>.ofImmutable(false);
}
