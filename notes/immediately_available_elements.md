# immediately available elements

...currently don't emit events!

1. Emit events in Scope.toStream like listen does.
2. Don't actually make elements available until next microtask or event.

Should state of scoped elements itself be an observable?

Can ScopedElements emit its own Available event?

What if...

* Available implements StoryElement
* ScopedElements parameterized with Available

ScopedElement?

Are all elements scoped? Not necessarily. But they all emit events.

So far, an event and its state change have been effective instantaneous together. An event happens,
then the associated state change is visible, before other listeners react. We could make the event
fire synchronously, like the state change, though that would be a special case. That is, so far an
event's changes have never been visible before the event has been published.

Are there any other cases where we'd want to publish an event about a state change that has
already happened? Thinking about observables and UI synchronization.

Should that actually be the other way around normally then? (change then event).

Again, the way I've implemented events so far is it hasn't really mattered – no caller can see
a state change before an event, and every caller sees the state change after the event. If the 
state changed in a microtask or future first, then subscriptions were called, it would look the 
same. But if state was changed within an event loop, other code could see the state change before
event listeners did.

For observables though (and so scopes), the state change _is_ visible immediately, before listeners
are fired (though there are also synchronous listeners).

What if we modeled event queue as an Observable or, more fundamentally an EventStream? (which 
both Observable and Events are based on).

Change listeners would be fired in microtasks. Events would all propagate through microtasks until 
we were waiting on either time or user input.
