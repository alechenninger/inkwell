`Scope` is a simple abstraction for something that has a defined start and end that can be listened 
to.

Right now this is mainly used for UI listening to the addition or removal of elements.

Currently I have scope listeners fired synchronously, in-frame. Should we do this? It looks like the
usage pattern is to enter or exit scope in a separate future.

Something can only be in scope if its underlying condition is true. But what about the reverse, if 
its underlying condition is true, must the thing be in scope?

Why not treat scope like any other state? It is simply boolean state that can be observed 
asynchronously: true (in scope) or false (out of scope).

It would be simpler to implement with the Observable type and treat it as just an Observed boolean
value.
