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
  var runAway = attack.exclusiveWith('Run away!');

  attack.onUse.when(() {
    attackDragon(dragonStandoff, sword);
  });

  runAway.onUse.when(() async {
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

  deflectWithSword.onUse.when(() async {
    dialog.narrate('You survive, but your sword has melted!',
        scope: dragonStandoff);
    options.oneTime('Throw the stub of your sword at the dragon.',
        available: dragonStandoff);
    sword.isMelted.value = true;
    await dragonStandoff.enter();
  });

  deflectWithShield.onUse.when(() async {
    await scenes.oneTime().enter();
    dialog.narrate('Your shield sets aflame and you suffer terrible burns.');
  });

  dash.onUse.when(() async {
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

  // TODO: how to make reply exclusive with options
  var whosThere = thisWay.addReply("Who's there!?");

  var follow = options.oneTime('Follow the mysterious voice',
      available: whosThere.availability.and(runningAway));
  var hide = follow.exclusiveWith('Hide',
      available: whosThere.availability.and(runningAway));

  var player = dialog.voice(name: 'Bob');
  var mysteriousVoice = dialog.voice(name: '(mysterious voice)');

  whosThere.onUse.when(() async {
    player.say("Who's there!?");
  });

  follow.onUse.when(() async {
    await scenes.oneTime().enter();

    dialog.narrate('You hurry along toward the dark shapes ahead.');

    player.say('What are you doing here?');

    var toMysteryVoice = mysteriousVoice.say('I could ask you the same thing.');
    var needDragonScales = toMysteryVoice.addReply('I need dragon scales');
    var sayNothing = toMysteryVoice.addReply('...');

    needDragonScales.onUse.when(() {
      player.say('I need dragon scales.');
      mysteriousVoice.say('Good luck with that.');
    });

    sayNothing.onUse.when(() {});
  });

  hide.onUse.when(() async {
    await scenes.oneTime().enter();
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

extension When<T> on Stream<T> {
  StreamSubscription<T> when(Function() callback) {
    return listen((_) {
      callback();
    });
  }
}
