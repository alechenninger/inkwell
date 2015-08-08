# notes

## design

### begin event
removed 'begin' event: RunScript function runs at the start, it's synchronous,
so just do everything you would do during or before a 'begin' event.

### saving
save user interactions only, replay with fake timer. anything else is an optimization
will this retain "happens before" relationship with all events? I think so, because to fake timer, all non-duration based things are effectively instantaneous.

UI state must be tracked by non-presentation components.
presentation must be able to be switched at any time. or at least toggled off/on.

#### replaying saved events
order | seconds
1|0.0 - event A (schedules event B)
2|0.0 - event B (schedules event c and d)
3|0.0 - event C (schedules event e 1 sec in future and f 2 secs in future)
4|0.0 - event D (schedules event g .5 sec in future and h 2 secs in future)
5|0.5 - event G
6|1.0 - event E
7|2.0 - event F
8|2.0 - event H

fast forward to 06
runs block
new future event a -> queues fake timer
starts ff, goes to first timer in queue,
schedules event B in next event loop
schedules another ff loop after that
event b runs -> queues fake timer event C and D
ff loop runs
schedules c in next loop
schedules d in next loop
schedules another ff loop after that

### is everything an 'event'?
should everything really be an 'event'? should separate what scripts listen to
vs what ui's listen to? scripts listen to things by name, ui listen to things
by type.

### modular UI
options module
map module
inventory module

these things aren't isolated to UI though.

(Once once, Emit emit, Map modules) {
  Options options = modules[Options];
  Inventory inv = modules[Inventory];
  Dialog dialog = modules[Dialog];

}

modules maintain state. UI presentation interacts with modules.

Service per module or one service for all modules?
Compose UI of modules... but they kind of have to be aware of one another?
Or you have a container framework but eh...

class HtmlOptions {
  final Options options;

  HtmlOptions(Map modules): this.options = modules[Options];
}

How do presentation classes know about important state changes?
- Events are emitted (by modules or by scripts directly?)
  I think might not want to emit directly because you could have different
  implementations of the module API actually?
- Callbacks are registered
- The presentation classes /are/ the module impls... but then if you wanted to
  swap out you'd have redundant state storage impls and other redundant
  complications (such as handling of exclusive options).

Module:
- handle complex state arrangement based on script usage
- emit straightforward events for UI after state change

UI:
- handles events to update UI
- handles events from user to propagate back to modules
- indicates user events which should be saved to replay

now what should the input be to a UI component?

OptionsDisplay:
(Options options)
or
(Set<String> getOptions(), void selectOption(String))

addUi((modules) => new OptionsDisplay(modules[Options]))

addModule(Option, (emit) => new Option(emit));

Would you ever want to swap out module implementations? (Maybe not even testing?)
Mainly just want to be able to swap out UI layer.
(So could define modules with script).

Coupling...
story -> module API
ui -> 1. module API or 2. emitted events only or 3. neither
3 neither would accept functions...
Set<String> getOptions(), void selectOption(String),
Stream<Event> additions, Stream<Event>, removals
save(Event);
replay(Event);


save(() => options.use("foo"));

module 'interface'

OptionsInterface oi ... or just an alt impl of same API?

oi.use(foo)

emit(new SaveEvent(this, "use", ["foo"]))
