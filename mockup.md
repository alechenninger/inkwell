So turns out we can fake time passage with custom dart Zones (see quiver.testing.fakeAsync)
This changes things a bit.

So there are a few options:
1. Save cached state. This is what's implemented ish currently.
   Pro:
     - Simple
     - Clear compatibility rules: json format read and written
     - Quick load
   Con:
     - Everything must be serializable.
     - More verbose
2. Save all emitted events, replay all emitted events, ignore events emitted outside of journal,
   fake passage of time with new Zone.
   Pro:
     - Only events need to be serializable; actors/game/ui will rebuild their state
     - Could write plain dart... use streams and futures freely.
   Con:
     - Could we ignore something we aren't supposed to?
3. Save only user interface events, replay them, trick passage of time using zones.
   Would basically treat user events as another actor with events triggered at each of the times,
   then elapse the total time of the journal.
   Pro:
     - Only user interface events need to be serializable
     - Could write plain dart... use streams and futures freely.
   Con:
     - How to deal with UI?
       Less variance / flexibility. UI impl cannot have its own state. Need to be able to switch
       UI impl after replayed.

       UI has separate standard (or custom) components which maintain state. Then these have
       presentation impls.
4. Emit only state changes
   Have to be able to manage state explicitly / intercept all setters and replay.


Take a step back... what is best way to write a game like this?

Class per actor
Pro:
  - Simple
Con:
  - Maybe hard to organize. Each actor has cross-cutting concerns from beginning
    to end of story.

Organize by "chapters"?


Organize by "scene"?


Do we have to organize by 'anything' in particular? can top level code help?

once('begin').then((Options options) {
  options.add("Talk to Jill");
});

once('Talk to Jill').then((Jack jack, Jill jill, Emit emit) async {
  emit(new DialogEvent("Hi Jill, would you like to fetch some water?", from: jack, to: jill));

  await emit(new DialogEvent("Sure...", from: jill, to: jack), delay: new Duration(milliseconds: 500));
  await emit(new DialogEvent("See you at the top of the hill!", from: jill to: jack), delay: new Duration(seconds: 1))
  emit(new Narration("Jill runs off."));

  options.add("Follow Jill");
  options.add("Try to run past Jill");
  // TODO: options.addExclusive([...]) -- automatically removes other options when one is used; only allows one of list to be used

  once(new Duration(seconds: 10), named: "Jill gets to top of hill alone").then((Emit emit) {
    options.remove("Follow Jill");
    options.remove("Run past Jill");

    emit(todo("Not yet implemented"));
  });
});

once(anyOf("Follow Jill", "Try to run past Jill")).then(() {
  // Could also define this in the event handler for "Jill gets to top of hill alone"...
  // Something like, once(... unless: anyOf("Follow Jill", "Try to run past Jill"))
  // or something like that...
  removeEventHandler("Jill gets to top of hill alone");
});

once("Follow Jill").then((Options options) {
  // This is not needed if use options.addExclusive as mentioned above
  options.remove("Try to run past Jill");

  // TODO...
});




"random" numbers...

randoms:
  name: 42
user_events: # (or options... depends on if you can 'input' other things than options)
  -
    timestamp: 012312333
    option: "foo"
  -
    timestamp: 012353477
    option: "bar"






--------
now with modules:

```
(Once once, Emit emit, Map modules) {
  Options options = modules[Options];
  Dialog dialog = module[Dialog];

  emit(options.add("foo"));

  emit(dialog.event("blah blah", from: bill, to: bob));
  await emit(dialog.event("whu?", alias: "someone expresses confusion",
      delay: const Duration(seconds: 5),
      replies: ["Foobar", "Bar foo!"]);
  

  await emit(dialog.clear(alias: "silenced"));

  dialog.once({said: const RegExp(r"[Bb]ar")}).then((e) {

  });

  once(dialog.like({said: const RegExp("r[Bbar]")})).then((e) {

  });

}
```
