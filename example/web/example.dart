// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.example;

import 'package:august/options.dart';
import 'package:august/ui/html/html_ui.dart';
import 'package:august/ui/html/html_persistence.dart';
import 'package:quiver/time.dart';
import 'package:august/ui.dart';

import 'dart:html';

main() {
  // Boilerplate time tracking
  var clock = new Clock();
  var startTime = clock.now();

  Duration currentOffset() {
    return clock.now().difference(startTime);
  }

  // Instantiate modules
  var options = new Options();

  // Need a persistence strategy
  var persistence = new HtmlPersistence("example");

  // Create interactions manager using modules, persistence, and time tracking.
  var interactionsMngr = new InteractionManager(
      currentOffset, persistence, [new OptionsInteractor(options)]);

  // Create user interface objects using interactions manager.
  var optionsUi = new OptionsUi(options, interactionsMngr);
  new SimpleHtmlUi(querySelector("#example"), optionsUi);

  example(options);
}

example(Options options) {
  var slayTheDragon = options.newOption("Slay the dragon.");
  var befriendTheDragon = options.newOption("Befriend the dragon.");

  // Mutually exclusive... should make this easier to do for lots of options.
  befriendTheDragon.availability.onEnter.first.then((_) {
    slayTheDragon.available(befriendTheDragon.availability);
    befriendTheDragon.available(slayTheDragon.availability);
  });

  slayTheDragon.onUse.listen((_) {
    print("The dragon eats you.");
  });

  befriendTheDragon.onUse.listen((_) {
    print("The dragon eats you.");
  });
}
