# menu

- (re)start
- save
- load
- pause
- resume

Could these controls be a module itself?

Would have to push other aspects of `play` into the module. For example, user interface actions
shouldn't be persisted, but this will persist them.

But that might be doable also.

```dart
class MetaModule extends StoryModule {
  // aggregates all modules events
  Stream<Event> get events;
  
  // aggregates all modules serializers
  Serializers get serializers;
  
  // Looks like play signature
  MetaModule(Set<StoryModules> modules, 
      Persistence persistence, void Function() story) {
    // listen to actions, serialize, play in modules
    // Some actions are special: Start, Save, Load, Pause
    // These aren't persisted and invoke specific behaviors
    
    // load
    // reset state. play saved actions.
    
    // save
    // if not auto-saving after every action, buffer actions and then save on demand.
    // (buffer may be persisted also)
    // + add a 'checkpoint' action that does nothing but captures the current offset.
    
    // pause / resume
    // pauseable zone
  }
}
```

...kinda serves the same function as `play` in a different form. The form doesn't really have
much advantage I guess?

It would if it simplifies `play`.

```dart
void play(StoryModule module, UserInterface ui) {
  ui.play(module.events);
  ui.actions.listen((a) => a.run(module));
}
```

But this doesn't work because actions must be played by the right module (results in runtime error
otherwise). So a UI is coupled to multiple modules out of the gate. This is intentional.

So we at least need multi modules. Which means we can't have one module intercept all actions to
persist them. So I think this option is out.

So some kind of streams on UserInterface I guess separate from actions.

Should UI keep track of multiple stories? I don't think so.

Server-side, yes probably.

## save logic

...is a little clumsy right now.

Would like to push this to Narrator more.

Right now some of loading events has to be in Story within the FastForwarder. 
