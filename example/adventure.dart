// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.example;

import 'package:august/core.dart';
import 'package:august/ui.dart';

import 'dart:math';

Game game = new Game();

var self = new Self();
var adventurer = new Adventurer();
var ui = new Ui(document.body);

main() {
  game
    ..addActors([self, adventurer, ui])
    ..begin();
}

class Self extends Actor {
  @override
  void prepare(Game game) {}
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
  void prepare(Game game) {
    game.on[DialogEvent]
        .where((e) => e.target == this)
        .listen((e) {
          game
            .broadcastDelayed(new Duration(milliseconds: 300),
                new DialogEvent(this, "...", target: e.speaker))
            .thenBroadcastDelayed(new Duration(seconds: 2),
                _saySomethingRandomTo(e.speaker));
        });
  }

  @override
  void action(Game game) {
    game.broadcast(new AddOption(_talkToMe));
  }

  DialogEvent _saySomethingRandomTo(Actor target) {
    var thingToSay = _thingsToSay[_random.nextInt(_thingsToSay.length)];
    return new DialogEvent(this, thingToSay, target: target);
  }
}