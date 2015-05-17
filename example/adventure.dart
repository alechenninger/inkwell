// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.example;

import 'package:august/core.dart';
import 'package:august/ui.dart';

main() {
  var container = querySelector("body");

  Script script = (new ScriptBuilder()
    ..addActor(Jack, (game, script, [json]) => new Jack(game, json))
    ..addActor(Jill, (game, script, [json]) => new Jill(game, json))
    // TODO: UI as actor is nice in some ways but script is tied to UI now
    // Not exactly actually, the coupling is to the json format of the UI. If
    // two UI's share compatible toJson() they can be interchanged. The only
    // issue is that the dart definition of the script still defines the UI type.
    // It would be neat(unnecessary?) if scripts could be used like libraries and
    // UIs switched as needed. For instance, for mobile platforms (say, Sky).
    // They could export a script builder though that could be extended with a UI
    // of choice.
    ..addActor(SimpleHtmlUi, (game, script,
            [json]) => new SimpleHtmlUi(container, script, game, json))).build(
      "adventure", "1.0.0");

  new Game(script)..begin();
}

class Jack extends ActorSupport {
  bool hasWater = false;
  bool isBruised = false;
  bool isCrownBroken = false;

  @override
  Map get listeners => {};

  Jack(Game game, Map json) : super(game) {
    if (json != null) {
      hasWater = json["hasWater"];
      isBruised = json["isBruised"];
      isCrownBroken = json["isCrownBroken"];
    }
  }

  @override
  onBegin() {
    game.addOption(new Option("Ask Jill to fetch a pail of water.",
        new DialogEvent(
            "Jack", "Would you like to fetch a pail of water with me?",
            target: "Jill")));
  }

  Map toJson() => {
    "hasWater": hasWater,
    "isBruised": isBruised,
    "isCrownBroken": isCrownBroken
  };
}

class Jill extends ActorSupport {
  static const String _jackAsksToFetchWater = "jackAsksToFetchWater";

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
  Map<String, Listener> get listeners =>
      {_jackAsksToFetchWater: (DialogEvent e) {}};

  @override
  void onBegin() {
    on(DialogEvent)
      ..where(new EventTargetEq("Jill"))
      ..listen(_jackAsksToFetchWater);
  }

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
