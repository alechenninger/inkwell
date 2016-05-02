// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.example;

import 'package:august/august.dart';
import 'package:august/options.dart';
import 'package:august/ui/html/html_ui.dart';
import 'package:august/ui/html/html_persistence.dart';
import 'package:quiver/time.dart';

import 'dart:html';

main() {
  var clock = new Clock();
  var options = new OptionsModule();
  var ui = new SimpleHtmlUi(querySelector("#example"), options.ui);
  var persistence = new HtmlPersistence("example");

  var startTime = clock.now();

  Duration currentPlayTime() {
    return clock.now().difference(startTime);
  }

  options.ui.onInteraction.listen((interaction) {
    persistence.saveEvent(
        currentPlayTime(), "Options", "$interaction", interaction.toJson());
    interaction.run();
  });

  example(options.module);
}

example(Options options) {
  var slayTheDragon = options.newOption("Slay the dragon.");
  var befriendTheDragon = options.newOption("Befriend the dragon.");

  // Mutually exclusive... should make this easier to do for lots of options.
  slayTheDragon.available(befriendTheDragon.availability);
  befriendTheDragon.available(slayTheDragon.availability);

  slayTheDragon.onUse.listen((_) {
    print("The dragon eats you.");
  });

  befriendTheDragon.onUse.listen((_) {
    print("The dragon eats you.");
  });
}
