// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.example;

import 'package:august/core.dart';
import 'package:august/ui.dart';

import 'dart:math';

var self = new Self();
var adventurer = new Adventurer();
var ui = new Ui(document.body);

main() {
  Game.begin([self, adventurer, ui]);
}

class Self extends Actor {
  @override
  beforeBegin(Game game) {}
}

class Adventurer extends Actor {
  static const List _thingsToSay = const [
    "A mighty fine day, isn't it?",
    "What in the world could that be!",
    "Buffalo buffalo Buffalo buffalo buffalo."
  ];

  Random _random = new Random();

  Option _talkToMe;

  Adventurer() {
    _talkToMe = new Option.singleUse("Talk to Adventurer",
          new DialogEvent(self, "Hi there!", target: this));
  }

  @override
  beforeBegin(Game game) {
    game.on[DialogEvent]
        .firstWhere((e) => e.target == this)
        .then((e) async {
          await game.broadcastDelayed(new Duration(seconds: 1),
                new DialogEvent(this, "...", target: e.speaker));

          var punchMe = new Reply('Punch $Adventurer', new PunchEvent(e.speaker, this));
          var hugMe = new Reply('Hug $Adventurer', new HugEvent(e.speaker, this));

          game.on[punchMe.event]
              .first
              .then((e) {
                game.broadcast(new DialogEvent(this, "Ow!", target: e.puncher));
              });

          game.on[hugMe.event]
              .first
              .then((e) {
                game.broadcast(new DialogEvent(this, "How kind of you.", target: e.hugger));
              });

          game.broadcastDelayed(new Duration(seconds: 3),
              _saySomethingRandomTo(e.speaker, [punchMe, hugMe]));
        });
  }

  @override
  onBegin(Game game) {
    game.broadcast(new AddOption(_talkToMe));
  }

  ModalDialogEvent _saySomethingRandomTo(target, replies) {
    var thingToSay = _thingsToSay[_random.nextInt(_thingsToSay.length)];
    return new ModalDialogEvent(this, thingToSay, target, replies);
  }
}

class PunchEvent extends TargetedEvent {
  final Actor puncher;
  final Actor target;

  PunchEvent(this.puncher, this.target);
}

class HugEvent extends TargetedEvent {
  final Actor hugger;
  final Actor target;

  HugEvent(this.hugger, this.target);
}