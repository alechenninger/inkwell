// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.example;

import 'package:august/core.dart';
import 'package:august/modules.dart';
import 'package:august/html.dart';

main() {
  var container = querySelector(".ui-container");

  start(jackAndJillV1,
      uis: [SimpleHtmlUi.forContainer(container)],
      persistence:
          new NoopPersistance() /*new HtmlPersistence(jackAndJillV1)*/);
}

var jackAndJillV1 = new Script(
    "Jack and Jill", "1.0.0", [new OptionsDefinition(), new DialogDefinition()],
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
    emit("Jill gets to top of hill alone",
        delay: const Duration(seconds: 10), canceller: jillBeatsJack);

    once("Jill gets to top of hill alone").then((_) async {
      options.removeIn(["Follow Jill", "Try to run past Jill"]);

      dialog.clear();
      await dialog.add("I beat you!", from: "Jill", to: "Jack");

      await dialog.add("C'mon, I'll wait.",
          from: "Jill", to: "Jack", delay: const Duration(seconds: 2));

      options.add("Climb up hill alone.",
          named: "Follow Jill", delay: const Duration(seconds: 1));
    });

    once("Follow Jill").then((_) async {
      jillBeatsJack.cancelled = true;
      dialog.clear();
      dialog.add("So what do you want this water for anyway?",
          from: "Jill",
          to: "Jack",
          delay: const Duration(seconds: 3),
          replies: new Replies(
              ["I don't know actually!", "I'm really thirsty."],
              modal: true));

      dialog
          .onceReply(
              reply: "I don't know actually!",
              forDialog: "So what do you want this water for anyway?")
          .then((_) {
        dialog.add("I don't know actually!", from: "Jack", to: "Jill");
        dialog.add("Seriously?",
            from: "Jill", to: "Jack", delay: const Duration(milliseconds: 500));
      });
    });

    once("Try to run past Jill").then((_) {
      jillBeatsJack.cancelled = true;
    });
  });
});
