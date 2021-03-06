// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:html';
import 'dart:math';

import 'package:inkwell/inkwell.dart';
import 'package:inkwell/dialog.dart';
import 'package:inkwell/options.dart';
import 'package:inkwell/prompts.dart';
import 'package:inkwell/scenes.dart';
import 'package:inkwell/ui/html/html_persistence.dart';
import 'package:inkwell/ui/html/html_ui.dart';

void main() {
  var n = Narrator(example, HtmlArchive('example'), Stopwatch(), () {
    var scenes = Scenes();
    var options = Options(
        defaultScope: () => scenes.currentScene.cast<Scope>().orElse(always));
    var dialog = Dialog(
        defaultScope: () => scenes.currentScene.cast<Scope>().orElse(always));
    var prompts = Prompts();
    return Palette({scenes, options, dialog});
  });

  // Present the story with HTML
  SimpleHtmlUi(n, querySelector('#example'));
}

void example(Palette p) async {
  dragonStandoff(p);
}

void dragonStandoff(Palette p) async {
  var options = p<Options>();

  var dragonStandoff = await p<Scenes>().reentrant().enter();
  var sword = Sword();

  p<Dialog>().narrate('A dragon stands before you!');

  await delay(seconds: 1);

  var attack = options.oneTime('Attack it!');
  var runAway = options.limitedUse('Run away!', exclusiveWith: attack.uses);

  attack.onUse.when(() {
    attackDragon(p, dragonStandoff, sword);
  });

  runAway.onUse.when(() async {
    dragonStandoff.done();
    runAwayFromDragon(p, sword);
  });
}

void attackDragon(Palette p, Scene dragonStandoff, Sword sword) async {
  var scenes = p<Scenes>();
  var options = p<Options>();
  var dialog = p<Dialog>();

  await scenes.oneTime().enter();

  dialog.narrate('The dragon readies its flame...');

  await delay(seconds: 1);

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

void runAwayFromDragon(Palette p, Sword sword) async {
  var scenes = p<Scenes>();
  var options = p<Options>();
  var dialog = p<Dialog>();

  await scenes.oneTime().enter();

  dialog.narrate('Running away.');

  await delay(seconds: 1);

  if (sword.isMelted()) {
    dialog.narrate(
        'Your hot sword burns through its holster and tumbles behind you.');
  }

  var thisWay = dialog.add('This way!');

  await delay(seconds: 1);

  var whosThere = thisWay.addReply("Who's there!?");

  var follow = options.limitedUse('Follow the mysterious voice',
      exclusiveWith: whosThere.uses);
  var hide = options.limitedUse('Hide', exclusiveWith: whosThere.uses);

  var player = dialog.voice(name: 'Bob');
  var mysteriousVoice = dialog.voice(name: '(mysterious voice)');

  whosThere.onUse.when(() async {
    player.say("Who's there!?");
  });

  follow.onUse.when(() async {
    await scenes.oneTime().enter();

    dialog.narrate('You hurry along toward the dark shapes ahead.');

    await delay(seconds: 1);

    player.say('What are you doing here?');

    await delay(seconds: 1);

    var toMysteryVoice = mysteriousVoice.say('I could ask you the same thing.');

    await delay(seconds: 1);

    var needDragonScales = toMysteryVoice.addReply('I need dragon scales');
    var sayNothing = toMysteryVoice.addReply('...');

    needDragonScales.onUse.when(() async {
      player.say('I need dragon scales.');

      await delay(seconds: 1);

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
