// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.example;

import 'package:august/core.dart';
import 'package:august/ui.dart';

main() {
  var registry = new Registry()
    ..registerActor(Jack, () => new Jack(), (m) => new Jack.fromJson(m))
    ..registerActor(Jill, () => new Jill(), (m) => new Jill.fromJson(m));

  registry.registerListener("jackSaysHi", Jill,
      (DialogEvent event, Jill jill, Game game) {
    game.broadcast(new DialogEvent(jill, "Would you like to fetch some water "
        "from the top of that hill?", target: event.speaker));
    game.subscribe("agreeToFetchWater", Jill,
        filter: new EventTypeEq(DialogEvent));
  });

  registry.registerListener(
      "agreeToFetchWater", Jill, (DialogEvent event, Jill jill, Game game) {
    game.broadcast(new DialogEvent(jill, "Great!", target: event.speaker));
  });
}

class Jack implements JsonEncodable {
  bool hasWater = false;
  bool isBruised = false;
  bool isCrownBroken = false;

  Jack();

  Jack.fromJson(Map json) {
    hasWater = json['hasWater'];
    isBruised = json['isBruised'];
    isCrownBroken = json['isCrownBroken'];
  }

  @override
  Map toJson() => {
    "hasWater": hasWater,
    "isBruised": isBruised,
    "isCrownBroken": isCrownBroken
  };
}

class Jill implements JsonEncodable {
  bool hasWater = false;
  bool isBruised = false;
  Mood mood = Mood.happy;

  Jill();

  Jill.fromJson(Map json) {
    hasWater = json['hasWater'];
    isBruised = json['isBruised'];
    mood = new Mood.fromJson(json['mood']);
  }

  @override
  Map toJson() => {"hasWater": hasWater, "isBruised": isBruised, "mood": mood};
}

class Mood implements JsonEncodable {
  static const Mood happy = const Mood("happy");
  static const Mood unhappy = const Mood("unhappy");

  final String mood;

  const Mood(this.mood);
  Mood.fromJson(Map json) : mood = json['mood'];

  @override
  Map toJson() => {"name": mood};
}
