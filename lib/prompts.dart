import 'august.dart';

class Prompts extends Module<PromptsUi> {
  final _promptsCtrl = StreamController<Prompt>();

  Interactor interactor() {
    // TODO: implement interactor
    return null;
  }

  String get name => 'Prompts';

  @override
  PromptsUi ui(InteractionManager mgr) => PromptsUi(this, mgr);

  Prompt add(String text) => Prompt(this, text);
}

class Prompt {
  final String text;

  final Prompts _prompts;
  final _entries = Publisher<EnterPromptEvent>();

  final _available = SettableScope<void>.entered();

  Future<EnterPromptEvent> get onEnter => _entries.event;

  Prompt(this._prompts, this.text) {
    _prompts._promptsCtrl.add(this);
  }

  Future<EnterPromptEvent> enter(String input) {
    return _entries.publish(EnterPromptEvent(this, input), check: () {
      (ScopeAsValue()..within(_available)).observed.nextValue;
    }, sideEffects: () { _available.exit(null); });
  }
}

class PromptAlreadyEnteredException implements Exception {
  final Prompt prompt;

  PromptAlreadyEnteredException(this.prompt);
}


class PromptsUi {
  final Prompts _prompts;
  final Sink<Interaction> _interactions;

  PromptsUi(this._prompts, this._interactions);
}

class UIPrompt {
  final Prompt _prompt;
  final Sink<Interaction> _interactions;

  UIPrompt(this._prompt, this._interactions);

  String get text => _prompt.text;

  void enter(String input) {
    _interactions.add(_EnterPrompt(input));
  }
}

class _EnterPrompt extends Interaction {
  final String input;

  _EnterPrompt(this.input);

  String get moduleName => '$Prompts';

  String get name => '$_EnterPrompt';

  Map<String, dynamic> get parameters => {'input': input};

}

class EnterPromptEvent {
  final Prompt prompt;
  final String input;

  EnterPromptEvent(this.prompt, this.input);
}
