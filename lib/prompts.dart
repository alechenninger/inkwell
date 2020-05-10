import 'package:august/src/scoped_object.dart';

import 'august.dart';
import 'input.dart';
import 'src/events.dart';
import 'src/persistence.dart';
import 'src/scope.dart';

class Prompts extends Emitter {
  final GetScope _defaultScope;
  final _prompts = ScopedEmitters<Prompt, String>();

  Prompts({GetScope defaultScope = getAlways}) : _defaultScope = defaultScope;

  Stream<Event> get events => _prompts.events;

  Prompt add(String text, {CountScope exclusiveWith, Scope available}) {
    var prompt = Prompt(text,
        entries: exclusiveWith, available: available ?? _defaultScope());

    _prompts.add(prompt, prompt.availability,
        key: prompt.text,
        onAvailable: () => PromptAvailable(text),
        onUnavailable: () => PromptUnavailable(text));

    return prompt;
  }
}

class Prompt with Available implements Emitter {
  Prompt(this.text, {CountScope entries, Scope available = always})
      : entries = entries ?? CountScope(1) {
    _available = available.and(this.entries);
  }

  final String text;

  final CountScope entries;

  Scope _available;
  Scope get availability => _available;

  final _onEntry = Events<PromptEntered>();
  Stream<Event> get events => _onEntry.stream;

  Future<PromptEntered> enter(String input) async {
    var e = await _onEntry.event(() {
      if (!isAvailable) {
        throw PromptNotAvailableException(this);
      }

      return PromptEntered(text, input);
    });

    entries.increment();

    return e;
  }
}

class PromptNotAvailableException implements Exception {
  final Prompt prompt;

  PromptNotAvailableException(this.prompt);
}

class EnterPrompt extends Action<Prompts> {
  final String prompt;
  final String input;

  EnterPrompt(this.prompt, this.input);

  String get moduleName => '$Prompts';

  String get name => '$EnterPrompt';

  Map<String, dynamic> get parameters => {'input': input};

  void run(Prompts controller) {
    var it = controller._prompts.available[prompt];
    if (it == null) {
      throw StateError('prompt not available');
    }
    it.enter(input);
  }
}

class PromptEntered extends Event {
  final String prompt;
  final String input;

  PromptEntered(this.prompt, this.input);
}

class PromptAvailable extends Event {
  final String prompt;

  PromptAvailable(this.prompt);
}

class PromptUnavailable extends Event {
  final String prompt;

  PromptUnavailable(this.prompt);
}
