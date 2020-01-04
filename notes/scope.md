`Scope` is a simple abstraction for something that has a defined start and end that can be listened 
to.

Right now this is mainly used for UI listening to the addition or removal of elements.

Currently I have scope listeners fired synchronously, in-frame. Should we do this? It looks like the
usage pattern is to enter or exit scope in a separate future. 
