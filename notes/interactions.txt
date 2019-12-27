Considering all interactions through single set of abstractions instead of each module repeating
these with some common interfaces.

Common to all actions available to player:

- visibility
- availability

Related, it's nice to base the logic off of core dart library primitives like Streams, but it is the
cause of a lot of copy and paste and these conventions are not codified anywhere. Encapsulating
interactions could solve this problem as well.

StreamController<..Event>(sync: true) -> Publisher()

publisher.publishIf(preconditions, sideeffects, event)

Does this cover *all* possible interactions? Consider other kinds of input, like free text.
