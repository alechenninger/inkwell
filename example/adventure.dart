// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.example;

import 'package:august/core.dart';
import 'package:august/ui.dart';

var director = new Game();
var self = new Self();
var adventurer = new Adventurer();
var ui = new Ui(document.body);
var journal = new Journal(shouldLog: true);

main() {
  new Story([self, adventurer, journal, ui], director).begin();
}

talkToAdventurer(String words) {
  director.broadcast(new DialogEvent(self, words, target: adventurer));
}

class Self extends Actor {
  @override
  void prepare(Game d) {}
}

class Adventurer extends Actor {
  @override
  void prepare(Game d) {
    d.on[DialogEvent]
        .where((e) => e.target == this)
        .listen((e) {
          d.broadcast(new DialogEvent(this, "Hi there!", target: e.speaker));
        });
  }
}