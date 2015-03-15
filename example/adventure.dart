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

  final Random _random = new Random();

  @override
  void prepare(Game game) {
    game.on[DialogEvent]
        .where((e) => e.target == this)
        .listen((e) {
          game.broadcast(new DialogEvent(this, _randomThingToSay(),
              target: e.speaker));
        });
  }

  @override
  void action(Game game) {
    game.broadcast(
        new AddOption(
            new Option.singleUse("Talk to Adventurer",
                new DialogEvent(self, "Hi there!", target: this))));
  }

  String _randomThingToSay() {
    return _thingsToSay[_random.nextInt(_thingsToSay.length)];
  }
}