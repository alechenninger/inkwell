# client-server

UI -> serialize actions -> server -> module -> play actions
server -> serialize UI events -> client -> module -> stream events -> UI

serialize actions
- module
- actionName
- parameters

play actions
- each module understands how to play back by action name and parameters

serialize UI events
- module (ex: august.options)
- event (ex: OptionAvailable)
- parameters (ex: {text: 'option'})

play UI events
- each module has UI counterpart that knows how to deserialize UI events into typed streams
- the UI counterpart can also serialize actions

e.g.

```dart
class ClientOptionsUi {
  final Stream<UiEvent> _events;
  final Sink<Interaction> _actions;

  ClientOptionsUi(this._events, this._actions);
  
  Stream<UiOption> get onOptionAvailable => _events
      .where((e) => e.event == 'OptionAvailable')
      .map((e) => UiOption(_actions, e.parameters['text'] as String));
}
```

```dart
class UiOption {
  final String _text;
  final Stream<OptionUsed> _uses;
  final Stream<OptionUnavailable> _unavailable;
  final Sink<Interaction> _interactions;

  String get text => _text;

  UiOption(this._interactions, this._events, this._text);
  // TODO: fork events based on uses/unavail for this option

  void use() {
    _interactions.add(_UseOption(text));
  }

  Stream<UiOption> get onUse => _uses.map((e) => this);

  Stream<UiOption> get onUnavailable => _unavailable.map((e) => this);
}
```

Should have shared model with server and client for ser/deser.

Each module could have own server/client interface

Could have stream addition that splits out multiple streams based on mutually exclusive predicates. 
So rather than every listener evaluating predicate against every event, let one listener check every
event and route.
