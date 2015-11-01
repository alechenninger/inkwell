// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.example;

import 'package:august/core.dart';
import 'package:august/html.dart';
import 'package:august/modules.dart';

// Some boilerplate code to get things started. This will probably look very
// different in the future.
main() {
  var container = querySelector(".ui-container");

  // Here we "start" our "script": jackAndJillV1.
  // We'll talk more about our script below.
  // We also pass in user interfaces here, as well as some persistence
  // mechanism. Don't worry about this for now.
  start(jackAndJillV1,
      uis: [SimpleHtmlUi.forContainer(container)],
      persistence:
          new NoopPersistance() /*new HtmlPersistence(jackAndJillV1)*/);
}

// Here is our script. Notice it has a name, version, and a list of module
// definitions passed to it. Modules give scripts high level functionality, and
// allow user interfaces to interact with a script. When we pass in a module
// definition, we can then use that module in our script's "block".
var jackAndJillV1 = new Script(
    "Jack and Jill", "1.0.0", [new OptionsDefinition(), new DialogDefinition()],

// This is our script's "block". A "block" contains the body of the story and
// all of its logic and events. A "block" is a function that is called with a
// "Run" and a map of modules passed to it. A "Run" represents the current
// running process for the story: it allows you to interact with the world by
// emitting and listening to events. Usually you'll only use this indirectly, by
// way of the modules.
    (Run run, Map modules) {
  // We passed in two module definitions above: OptionsDefinition and
  // DialogDefinition. Now here we can retrieve the Options and Dialog modules
  // from the modules map passed to the block.
  Options options = modules[Options];
  Dialog dialog = modules[Dialog];

  // once and emit are common functions used to interact with events. Then are
  // members of the "run" which we reassign here to shorthand variables, "once"
  // and "emit".
  Once once = run.once;
  Emit emit = run.emit;

  // Now we get to the interesting stuff. Our story begins with a single choice
  // for the player: "Talk to Jill". If the player selects this option, an event
  // will be emitted. We can listen for this event.
  options.add("Talk to Jill");

  // Here is where we assign a listener for that event. Just because we assign
  // a listener doesn't mean that this block code within the listener is ever
  // run. It is only run if the event occurs. Adding a listener is a separate
  // step from responding to the occurrence of an event.
  once("Talk to Jill").then((_) async {
    // Inside this block is what happens if the "Talk to Jill" event occurs.
    // Since the player picked "Talk to Jill", we add dialog for the player
    // (Jack) to do just that.
    dialog.add('Hi Jill, would you like to fetch some water?',
        from: "Jack", to: "Jill");

    // When we interact with modules or emit events in a block, they don't show
    // up immediately. We are enqueueing those events in the native event loop.
    // That means if we want dialog to happen in a timed sequence, and not show
    // up all at once, we need to pass some delay to the dialog, and use the
    // "await" keyword to prevent code following that line from being executed
    // until the delay has passed and the dialog has been presented. The lines
    // of code below add dialog to the screen with a delay, and wait for them to
    // show up on the screen before continuing. If we did not await, all of the
    // dialogs would be queued up at the same time.
    await dialog.add("Sure...",
        from: "Jill", to: "Jack", delay: const Duration(milliseconds: 500));
    await dialog.add("See you at the top of the hill!",
        from: "Jill", to: "Jack", delay: const Duration(seconds: 1));

    // So far we've only added dialog: speech. You can also add "narration"
    // which is not associated with any character, and allows a user interface
    // to display it differently from dialog.
    dialog.narrate("Jill runs off.");

    // At the start of the game we added an option to talk to Jill. We can also
    // add "exclusive" options. Of these options, added as a list, only one can
    // be used among them. Once one among them is used, all others are removed.
    options.addExclusive(["Follow Jill", "Try to run past Jill"]);

    // When you emit an event with a great delay (many seconds), often you may
    // want to cancel it based on what may happen until it's actually emitted.
    // To do this you can use a "Canceller". Pass a canceller when you are
    // emitting an event, and then you can set .cancel = true on the canceller
    // at a later time to prevent the event from ever being emitted.
    var jillBeatsJack = new Canceller();

    // Here we emit such an event with a delay of 10 seconds. If the player does
    // not choose one of the earlier options within 10 seconds, Jill gets to the
    // top of the hill alone and the story continues in a different way.
    emit("Jill gets to top of hill alone",
        delay: const Duration(seconds: 10), canceller: jillBeatsJack);

    // Here, we add a listener for if Jill gets to the top of the hill alone.
    once("Jill gets to top of hill alone").then((_) async {
      // Remove the previous available options: we didn't use any, and now they
      // are no longer relevant.
      options.removeIn(["Follow Jill", "Try to run past Jill"]);

      // Dialog builds up over time on the UI. Clearing the dialog on screen is
      // a literary and presentation device that can be useful to separate
      // scenes.
      dialog.clear();
      await dialog.add("I beat you!", from: "Jill", to: "Jack");

      await dialog.add("C'mon, I'll wait.",
          from: "Jill", to: "Jack", delay: const Duration(seconds: 2));

      options.add("Climb up hill alone.",
          named: "Follow Jill", delay: const Duration(seconds: 1));
    });

    // Here we add a listener for if the player chooses, "Follow Jill". Now we
    // have two branches in this story line: if the player chooses "Follow Jill"
    // or if the player waits for 10 seconds instead. Stories can branch very
    // heavily.
    once("Follow Jill").then((_) async {
      // Here we use the canceller we mentioned earlier. The player picked an
      // option, so we cancel the event that was going to be emitted if the
      // player did nothing.
      jillBeatsJack.cancelled = true;

      dialog.clear();

      // Dialogs can have replies. Think of them like inline options for a
      // specific dialog. Replies can also be "modal," which means the player
      // must reply before doing anything else.
      dialog.add("So what do you want this water for anyway?",
          from: "Jill",
          to: "Jack",
          delay: const Duration(seconds: 3),
          replies: new Replies([
            "I don't know actually!",
            "I'm really thirsty. [not yet implemented]"
          ], modal: true));

      // Some events need more criteria to be listened for than just a text
      // based identifier. For replies, we ues the dialog module to listen for
      // a specific one.
      dialog
          .onceReply(
              reply: "I don't know actually!",
              forDialog: "So what do you want this water for anyway?")
          .then((_) async {
        dialog.add("I don't know actually!", from: "Jack", to: "Jill");
        await dialog.add("Seriously?",
            from: "Jill", to: "Jack", delay: const Duration(milliseconds: 500));

        dialog.narrate("[not yet implemented]");
      });
    });

    // Here is the final option from earlier, represented a third branch in the
    // story already.
    once("Try to run past Jill").then((_) {
      jillBeatsJack.cancelled = true;

      dialog.clear();

      dialog.narrate("About halfway up the hill, you trip and fall.");

      dialog.add("Ow!", from: "Jack", delay: const Duration(seconds: 1));

      dialog.add("Are you okay?",
          from: "Jill",
          to: "Jack",
          named: "After Jack falls",
          delay: const Duration(seconds: 1),
          replies: new Replies([
            "I'm alright, thanks.",
            "Yeah, but I think I stained my jeans. [not yet implemented]",
            "My ankle... [not yet implemented]"
          ], modal: true));

      dialog
          .onceReply(
              reply: "I'm alright, thanks.", forDialogNamed: "After Jack falls")
          .then((_) async {
        dialog.add("I'm alright, thanks.");

        await dialog.narrate(
            "Jack brushes himself off, and continues up the hill.",
            delay: const Duration(seconds: 1));

        emit("Jill and Jack arrive at the top of the hill",
            delay: const Duration(seconds: 2));
      });

      dialog
          .onceReply(
              reply: "Yeah, but I think I stained my jeans.",
              forDialogNamed: "After Jack falls")
          .then((_) {
        dialog.add("Yeah, but I think I stained my jeans.");
      });

      once("Jill and Jack arrive at the top of the hill").then((_) {
        dialog.clear();
        dialog.narrate("[not yet implemented]");
      });
    });
  });
});
