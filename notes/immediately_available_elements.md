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

However, this produces a problem when combined with current design. Design elements which conflict:

* Object publishing own availability events
* Object coming into availability immediately upon construction
* Availability events using EventStream (event not published in future)

With these three constraints, an object which is available during construction will publish an
availability event to a listener. By the time the listener subscribes, the event is already 
published.

So either:

1. An object is never immediately available
2. An Available event is emitted somewhere else if immediately available (e.g. in ScopedElements)
3. The stream buffers until there are listeners (may have other bad consequences?)

2 can be accomplished in a couple of ways.

I said above availability could be modeled as observing a collection. The problem with actually
doing that in ScopedElements is that the elements themselves are not serializable.

That actually causes another problem: we could make available/unavailable reusable constructs
except that also requires the element itself to be serializable.

But the elements themselves can't be in practice. Their API is meant to be usable for writing
stories, which means they have some state which is about event management and the like. It would
be really cumbersome to have to serialize all that. And the UI wouldn't care about all that.

However there is a core of an element which is naturally serializable. It's the stuff we were
putting in the availability events. 

Wait–can built value handle serializing those elements? (ignoring the stuff we don't want to be
serialized) The readme makes it sound like it could, but I don't see how.

Regardless, we could move the core "value" of an element to a built value, and then make a generic
available event with this core value.

Is there any element that might not work with this pattern though? Do we mind always creating new
objects for state changes? For there to be visible state to the UI, this basically has to be true.

```dart
class Speech implements Built<Speech, SpeechBuilder> {
  @nullable
  String get speaker;
  String get markup;
  @nullable
  String get target;
  
  // snip...
}

class IsAvailable<T> extends Event implements Built<Available<T>, AvailableBuilder<T>> {
  T get element;
}

class IsUnavailable<T> extends Event implements Built<Unavailable<T>, UnavailableBuilder<T>> {
  T get elementKey;
}

abstract class ScopedElement<E extends ScopedElement<E>, S> extends StoryElement {
  Scope get availability;
  // Not great...
  S get state; // serializable
}

class SpeechElement extends ScopedElement<SpeechElement> {
  final Speech speech;
}

class ScopedElements<E extends ScopedElement<E>, K> extends StoryElement {
  void add(E element, {@required K key}) {
    // on available, emit IsAvailable<E.state>
    // if available now, emit now
    // on unavailable, emit IsUnavailable<key>
  }
}
```

Could possibly work better if story element is subtype of value?

Or just live with duplication and pass event to scopedelements.add?

Some way to get event from element interface?

Do we care if elements don't emit their own availability events? I think we do care, because 
availability is a per element construct, and it may come later.

Basically this comes down to: should elements be able to emit events during construction and if so,
how (such that something can actually listen to those events)?

