The current implementation of the event loop has been around for a while now but it's a bit
confusing to understand the conventions, and it may benefit from codifying those conventions, or
maybe event changing them. Let's reevaluate what's going on.

The first basic premise is that we are working with a language that is already based on an event
loop: Dart. And this matches another goal: to avoid creating a standalone language for scripting a
game, and build abstractions within an existing, richly-tool-assisted language. I have so far chosen
Dart for this purpose.

What does it mean to reuse the Dart event loop?

A very short review of how the Dart event loop works:

- There are events (or macrotasks) and microtasks
- At the end of either, the next microtask is drained and executed.
- Microtasks block rendering. Rendering is interleaved with events.
- Once there are no microtasks, the next event is drained and callbacks executed.

Your code responds to events and are run synchronously, single-threaded, when an event is processed.
A click happens, which gets queued, and processing that calls your callbacks.

Callbacks in turn may install more callbacks in response to other events.

Arbitrary functions may be scheduled using:

1. Zone.current.createTimer (which is ultimately what Future(() { /* stuff */ }) does) for events
2. Zone.current.scheduleMicrotask (which is ultimately what the top-level scheduleMicrotask(() {})
does) for microtasks

For more information, see https://webdev-angular4-dartlang-org.firebaseapp.com/articles/performance/event-loop

As far as I can tell (via a thorough reading of the changelog), none of this has changed with Dart
2. The only notable change in Dart 2 is that async (not async*) methods now run synchronously until
then first await statement inside the function (https://dart.dev/codelabs/async-await). Previously
the body of an async function was queued in a microtask. This makes switching from sync to async
functions more intuitive as it keeps the synchronous behavior the same.

What do we want from an event loop?

We want it to match a model that works well for scripting and executing stories. That is:

- A script is organized by emitting and listening to events.
  - Dart loop? Works.
- Events occur in a deterministic order such that replay of the same input produces the same output.
  - Dart loop? Works.
- Listeners are fired in a deterministic order such that replay of the same input produces the same
output.
  - Dart loop? Depends. I do not believe StreamControllers satisfy this requirement. More on this
  below.
- Listeners to the same event all have access to same, initial snapshot of the world. This has the
effect of organizing listener callbacks into a single "frame" of execution.
  - Dart loop? No, we need to implement this state management ourselves or with a library.
- Listeners also need access to the "next" state of the world, which necessarily may change from
callback to callback within a frame. This is why a deterministic order of listener callbacks is
important.
  - Dart loop? No, we need to implement this state management ourselves or with a library.
  - Is this really needed? An alternative would be to just wait to check the "next" state – schedule
  a callback, and in that callback check current state.
- UI should be fast, smooth, and decoupled.
  - Dart loop? Depends. I'm not sure StreamControllers satisfy this requirement, as callbacks are
  all triggered in microtasks which block rendering. That said, maybe we want that behavior in order
  to avoid exposing mid-frame states to the UI. Additionally, ideally we ran the entire story event
  loop in its own isolate and in that case it wouldn't matter that callbacks ran as microtasks.

```dart
import 'dart:core';

abstract class Events {
  Future schedule(Event event);
  Stream get events;
}
```

Example trying to drive at what should be synchronous vs not:

1. Option has multiple listeners
2. Option used
3. Listener 1 fires, consumes some limited resource
