// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.example;

import 'package:august/core.dart';
import 'package:august/modules.dart';

main() {
  start(jackAndJillV1, null /* TODO */);
}

class Jack {}

class Jill {}

var jackAndJillV1 = new Script("Jack and Jill", "1.0.0", [
  new OptionsModule(),
  new DialogModule()
], (Once once, Emit emit, Map modules) {
  // TODO: How to handle scope of these? IoC?
  Jack jack = new Jack();
  Jill jill = new Jill();

  Options options = modules[Options];
  Dialog dialog = modules[Dialog];

  options.add("Talk to Jill");

  once("Talk to Jill").then((_) async {
    dialog.add('Hi Jill, would you like to fetch some water?',
        from: "Jack", to: "Jill");

    await dialog.add("Sure...",
        from: "Jill", to: "Jack", delay: const Duration(milliseconds: 500));
    await dialog.add("See you at the top of the hill!",
        from: "Jill", to: "Jack", delay: const Duration(seconds: 1));
    dialog.narrate("Jill runs off.");

    options.add("Follow Jill");
    options.add("Try to run past Jill");
    // TODO: options.addExclusive([...]) -- automatically removes other options when one is used; only allows one of list to be used

    emit(new Event("Jill gets to top of hill alone"),
        delay: const Duration(seconds: 10));

    once("Jill gets to top of hill alone").then((_) {
      options.remove("Follow Jill");
      options.remove("Run past Jill");
    });
  });
});
