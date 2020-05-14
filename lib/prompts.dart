import 'package:built_value/serializer.dart';

import 'august.dart';
import 'modules.dart';

class Prompts extends StoryModule {
  final GetScope _defaultScope;
  final _prompts = ScopedElements<Prompt, String>();

  Prompts({GetScope defaultScope = getAlways}) : _defaultScope = defaultScope;

  @override
  // TODO: implement serializers
  Serializers get serializers => throw UnimplementedError();

  Stream<Event> get events => _prompts.events;

  Prompt add(String text, {CountScope exclusiveWith, Scope available}) {
    var prompt = Prompt(text,
        entries: exclusiveWith, available: available ?? _defaultScope());

    _prompts.add(prompt, prompt.availability, key: prompt.text);

    return prompt;
  }
}

class Prompt with Available implements StoryElement {
  Prompt(this.text, {CountScope entries, Scope available = always})
      : entries = entries ?? CountScope(1) {
    _available = available.and(this.entries);
    _events.includeStream(availability.toStream(
        onEnter: () => PromptAvailable(text),
        onExit: () => PromptUnavailable(text)));
   }

  final String text;

  final CountScope entries;

  Scope _available;
  Scope get availability => _available;

  final _events = Events();
  Stream<Event> get events => _events.stream;

  Future<PromptEntered> enter(String input) async {
    var e = await _events.event(() {
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
