# Event loop

The current implementation of the event loop has been around for a while now but it's a bit
confusing to understand the conventions, and it may benefit from codifying those conventions, or
maybe event changing them. Let's reevaluate what's going on.

The first basic premise is that we are working with a language that is already based on an event
loop: Dart. And this matches another goal: to avoid creating a standalone language for scripting a
game, and build abstractions within an existing, richly-tool-assisted language. I have so far chosen
Dart for this purpose.

## What does it mean to reuse the Dart event loop?

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
2. The only* notable change in Dart 2 is that async (not async*) methods now run synchronously until
then first await statement inside the function (https://dart.dev/codelabs/async-await). Previously
the body of an async function was queued in a microtask. This makes switching from sync to async
functions more intuitive as it keeps the synchronous behavior the same.

*: This doesn't mean throw statements will immediately throw, they will instead return a Future
completed with the error. Confirmed via testing in dartpad.

## What do we want from an event loop?

We want it to match a model that works well for scripting and executing stories. That is:

- A script is organized by emitting and listening to events.
  - Dart loop? Works.
- Events occur in a deterministic order such that replay of the same input produces the same output.
  - Dart loop? Works.
- Listeners are fired in a deterministic order such that replay of the same input produces the same
output.
  - Dart loop? Depends. I do not believe StreamControllers satisfy this requirement due to dart 
  doc's insistence that listeners are not all fired in order.
- UI should be fast, smooth, and decoupled.
  - Dart loop? Depends. I'm not sure StreamControllers satisfy this requirement, as callbacks are
  all triggered in microtasks which block rendering. That said, maybe we want that behavior in order
  to avoid exposing mid-frame states to the UI. Additionally, ideally we ran the entire story event
  loop in its own isolate and in that case it wouldn't matter that callbacks ran as microtasks.
  
Was in the above list, but removed:

- Listeners to the same event all have access to same, initial snapshot of the world. This has the
effect of organizing listener callbacks into a single "frame" of execution.
  - Dart loop? No, we need to implement this state management ourselves or with a library.
  - **Removed because unnecessarily complex. See below.**
- Listeners also need access to the "next" state of the world, which necessarily may change from
callback to callback within a frame. This is why a deterministic order of listener callbacks is
important.
  - Dart loop? No, we need to implement this state management ourselves or with a library.
  - Is this really needed? An alternative would be to just wait to check the "next" state – schedule
  a callback, and in that callback check current state.
  - **Removed because unnecessarily complex. See below.**

## New take

- Use dart event loop
- Create abstractions for scheduling events in a game-compatible way, potentially with other 
features like logging all events in a consistent way
- Fire listeners in independent microtasks like async controllers
- Maintain order of listeners
- State changes are synchronous, but can of course be scheduled as part of a future event.

Visually:

| Event loop 1 | Event loop 2        | Event loop 3        | Event loop 4           | Event loop 5 |
|--------------|---------------------|---------------------|------------------------|--------------|
| Click reply  | Click reply         | Click reply         | Click reply            | Click reply  |
|              | (mt) reply listener | (mt) reply listener | (mt) reply listener    | (mt) reply listener |
|              |                     | some event          | some event             | some event |
|              |                     | (mt) state change x | (mt) state change x    | (mt) state change x |
|              |                     | (mt) state change y | (mt) state change y    | (mt) state change y |
|              |                     | location change     | (mt) x change listener | (mt) x change listener |
|              |                     |                     | location change        | location change |
|              |                     |                     |                        | location change from x change (row 5) |

This is weird of course but technically possible: queued events may interact in odd ways. However, 
if this is the intention, it can still make sense. For example the narrative could be you have a 
spell that transports you somewhere if you are wounded a certain amount, and you get wounded after 
jumping out a window, so you change location twice in quick succession. The presentation of it just 
has to handle that. That is, the narrative explaining what happens to the player can account for 
this if we provide the abstractions for the author to do so. So for example perhaps that is 
text/visuals/audio associated with a scene or location transition.

### State changes

These need to be done asynchronously so event listeners all have access to the same state of the 
world when making decisions.

There is nothing to stop a script from being coded such that the state change is immediate and 
impacts other event listeners. I think the best we can do is make it easy to manage state that 
changes in the event queue.

Currently Observable listeners are fired synchronously. We may need both: synchronous to handle
state that is a function of other state–we do not want artifacts of eventual consistency that would
happen if the dependent state changed only in later tasks. I wrote the below about grouped state 
changes before I realized how Observable already worked today.

#### Grouped state changes

In [scope.md](scope.md), I'm considering changing scope to simply be an observable boolean flag.

But sometimes state changes need to move together. For example, if we use a boolean flag, but are
actually basing a scope on some other state, like a count. When increment the count to a certain 
value, we do that asynchronously, and it should effectively change the scope value at that time, not
in yet another future event.

Some state changes are grouped together; they are atomic. How to concisely say when this is 
appropriate?

In this case, the boolean flag is implementation detail–it's another representation of the same 
state. It's a function of some other state, maybe that's one reason to make a state change in the
same event / synchronously. Is that the only reason?

An elegant way to deal with that may be to use Observables and allow to listen to changes 
synchronously?

#### What if we actually don't need async state changes

What if **events** are async, but state changes synchronously?

Observable.map => synchronous stream
Observable.listen => asynchronous stream – listeners in microtask queue, before other events, to
ensure each state gets observed that should be
Events.listen => asynchronous stream - listeners in microtask queue, before other events, to ensure
each state gets observed that should be

Then choice is when to do state change now or tell the state change with an event?

Possible rule of thumb: if the state change could be described by a separate event, describe it as a
separate event.

For example:

1. (e1) dragon breathes fire
2. (l1) on breathe fire, then shield burns
2. (e2) shield burns (observable by a state change)

Creating a "chain" of events.

How do we coincide the state change with the event?

1. Listen to the event for the state change. Hide the event otherwise. If things want to listen to 
state change, they can listen to that, not the triggering event.
2. Allow events to have initial listeners or associated computation that fires before others. Maybe
they would just by virtue of "the thing creating them" would have "first dibs" to assign a listener
(as in 1).

Both are pretty trivial. Events already can be any function (2).

Should state listeners all fire synchronously? Probably not, this has some bad effects like

```dart
state.onChange(() { bar(); })
state.value = 1
foo();
// if sync state change, bar comes before foo. not right.
```

This wouldn't generally happen as written, but perhaps if it's buried in another function call it 
might accidentally.

Is there a downside to this?

Not really. If you need to "see the future" – schedule an event in the future, or listen to a future
or stream. Catching errors can help (e.g. in the option.use() case when it is already used. Instead
of checking for it to be used first, just use it and catch the error. If you want to just know if 
it was used, schedule an event or listen to onUse). 

##### Merging observables

Two options:

1. Build on top of mapping observables, which is a synchronous notification
2. Expose a synchronous broadcast stream from observables, use that to build merge

2 works well and probably has the cleanest and most sensible implementation. But I don't like that
it exposes a synchronous stream which can be misused, and that we have to expand our custom stream 
to produce both synchronous and asynchronous events.

One way to mitigate some downsides would be to make synchronous stream private.

### What else should all event streams have in common?

The fundamentals are above. But is there anything else that would be valueable?

For example, should all event streams produce events of a common supertype? Should they be logged in
a consistent way?

Another example of logging would be to keep track of and understand causality–the relationship of
listeners to their related events.

"X action taken. This caused: 1 ... 2 ... 3 ..."

Event
  catalyst: Event? // Maybe not nullable
  summary: String // Or just use toString?

EventContext

But how?

Around calling listener functions, track what event is being listened to
When events are published, use this as cause, if one is set
It would catch if events published during event listeners
When outside calling listener, set current event to null or some root event.

Maybe simpler:

Event listeners get called with event anyway. We could wrap them in something that tracks the 
event(s) that were sent to it?

```
var livingRoom = world.location();
var bedroom = world.location()..join(livingRoom);
var sleep = options.newOption(available: bedroom.whileIn.and(time.whileNight));
sleep.onUse(() {
    
});
```
