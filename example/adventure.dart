// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.example;

import 'package:august/core.dart';

main() {
  start(jackAndJillV1);
}

class Jack {}

class Jill {}

var jackAndJillV1 = new Script("Jack and Jill", "1.0.0",
    (Once once, Options options, Emit emit) {
  // TODO: How to handle scope of these? IoC?
  Jack jack = new Jack();
  Jill jill = new Jill();

  options.add("Talk to Jill");

  once("Talk to Jill").then((_) async {
    emit(new Dialog('Hi Jill, would you like to fetch some water?',
        from: jack, to: jill));

    await emit(new Dialog("Sure...", from: jill, to: jack),
        delay: const Duration(milliseconds: 500));
    await emit(
        new Dialog("See you at the top of the hill!", from: jill, to: jack),
        delay: const Duration(seconds: 1));
    emit(new Narration("Jill runs off."));

    options.add("Follow Jill");
    options.add("Try to run past Jill");
    // TODO: options.addExclusive([...]) -- automatically removes other options when one is used; only allows one of list to be used

    emit(new Event("Jill gets to top of hill alone"),
        delay: const Duration(seconds: 10));

    once("Jill gets to top of hill alone").then((_) {
      options.remove("Follow Jill");
      options.remove("Run past Jill");

      emit(new Todo("Not yet implemented"));
    });
  });
});
