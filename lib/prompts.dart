import 'august.dart';
import 'input.dart';
import 'src/persistence.dart';
import 'src/scope.dart';
import 'src/events.dart';

class Prompts extends Module<PromptsUi> {
  final _promptsCtrl = StreamController<Prompt>();

  Interactor interactor() {
    return PromptInteractor();
  }

  @override
  PromptsUi ui(Sink<Interaction> interactionSink) =>
      PromptsUi(this, interactionSink);

  Prompt add(String text) {
    var p = Prompt(this, text);
    _promptsCtrl.add(p);
    return p;
  }
}

class Prompt {
  final String text;

  final Prompts _prompts;
  final CountScope _count = CountScope(1);
  final _entries = Events<EnterPromptEvent>();

  Stream<EnterPromptEvent> get entries => _entries.stream;

  Prompt(this._prompts, this.text);

  Future<EnterPromptEvent> enter(String input) async {
    var e = await _entries.event(() {
      if (_count.isNotEntered) {
        throw PromptAlreadyEnteredException(this);
      }

      return EnterPromptEvent(this, input);
    });

    _count.increment();

    return e;
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

class EnterPromptEvent extends Event {
  final Prompt prompt;
  final String input;

  EnterPromptEvent(this.prompt, this.input);
}

class PromptInteractor extends Interactor {
  @override
  String get moduleName => 'august.Prompts';

  @override
  void run(String action, Map<String, dynamic> parameters) {
    // TODO: implement run
  }

}
