// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.example;

import 'package:august/core.dart';
import 'package:august/modules.dart';
import 'package:august/html.dart';

main() {
  var container = querySelector("body");

  start(jackAndJillV1,
      uis: [
        (interfaces) =>
            new SimpleHtmlUi(container, interfaces[Options], interfaces[Dialog])
      ],
      persistence: new HtmlPersistence(jackAndJillV1));
}

var jackAndJillV1 = new Script(
    "Jack and Jill", "1.0.0", [new OptionsModule(), new DialogModule()],
    (Run run, Map modules) {
  Options options = modules[Options];
  Dialog dialog = modules[Dialog];

  Once once = run.once;
  Emit emit = run.emit;

  options.add("Talk to Jill");

  once("Talk to Jill").then((_) async {
    dialog.add('Hi Jill, would you like to fetch some water?',
        from: "Jack", to: "Jill");

    await dialog.add("Sure...",
        from: "Jill", to: "Jack", delay: const Duration(milliseconds: 500));
    await dialog.add("See you at the top of the hill!",
        from: "Jill", to: "Jack", delay: const Duration(seconds: 1));
    dialog.narrate("Jill runs off.");

    options.addExclusive(["Follow Jill", "Try to run past Jill"]);

    var jillBeatsJack = new Canceller();
    emit(new Event("Jill gets to top of hill alone"),
        delay: const Duration(seconds: 10), canceller: jillBeatsJack);

    once("Jill gets to top of hill alone").then((_) {
      options.removeIn(["Follow Jill", "Try to run past Jill"]);
    });

    once("Follow Jill").then((_) async {
      jillBeatsJack.cancelled = true;
      dialog.clear();
      dialog.add("So what do you want this water for anyway?",
          from: "Jill", to: "Jack", delay: const Duration(seconds: 3));
    });

    once("Try to run past Jill").then((_) {
      jillBeatsJack.cancelled = true;
    });
  });
});
