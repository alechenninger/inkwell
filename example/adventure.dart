// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.example;

import 'package:august/core.dart';
import 'package:august/ui.dart';

main() {
  Script script = new Script("adventure", "1.0.0")
    ..addActor(Jack, (game, [json]) => new Jack(game, json))
    ..addActor(Jill, (game, [json]) => new Jill(game, json));

  Game game = new Game(script)..begin();
}

class Jack extends Actor {
  static const String _jillSaysHi = "jillSaysHi";

  bool hasWater = false;
  bool isBruised = false;
  bool isCrownBroken = false;

  @override
  Map get listeners => {_jillSaysHi: (DialogEvent event) {}};

  Jack(Game game, Map json) : super(game) {
    if (json != null) {
      hasWater = json["hasWater"];
      isBruised = json["isBruised"];
      isCrownBroken = json["isCrownBroken"];
    }
  }

  @override
  onBegin() {
    on(DialogEvent)
      //..where(eventTarget.is(this))
      ..listen(_jillSaysHi);
  }

  Map toJson() => {
    "hasWater": hasWater,
    "isBruised": isBruised,
    "isCrownBroken": isCrownBroken
  };
}

class Jill extends Actor {
  bool hasWater = false;
  bool isBruised = false;
  Mood mood = Mood.happy;

  Jill(Game game, Map json) : super(game) {
    if (json != null) {
      hasWater = json["hasWater"];
      isBruised = json["isBruised"];
      mood = new Mood.fromJson(json["mood"]);
    }
  }

  @override
  Map<String, Listener> get listeners => {};

  @override
  void onBegin() {}

  Map toJson() => {"hasWater": hasWater, "isBruised": isBruised, "mood": mood};
}

class Mood {
  static const Mood happy = const Mood("happy");
  static const Mood unhappy = const Mood("unhappy");

  final String mood;

  const Mood(this.mood);

  Mood.fromJson(Map json) : mood = json['mood'];

  Map toJson() => {"mood": mood};
}
