import 'package:august/src/event_stream.dart';
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
    var prompt = _prompts.add(
        (events) => Prompt(events, text,
            entries: exclusiveWith, available: available ?? _defaultScope()),
        (p) => p.availability,
        (p) => p.text);

    return prompt;
  }
}

class Prompt with Available implements StoryElement {
  final String text;

  final CountScope entries;

  Scope _available;

  Scope get availability => _available;
  final EventStream<Event> _events;

  Stream<Event> get events => _events;

  Prompt(EventStream<Event> events, this.text,
      {CountScope entries, Scope available = always})
      : entries = entries ?? CountScope(1),
        _events = events.childStream() {
    _available = available.and(this.entries);
    _events.includeStream(availability.toStream(
        onEnter: () => PromptAvailable(text),
        onExit: () => PromptUnavailable(text)));
  }

  void enter(String input) {
    if (isNotAvailable) {
      throw PromptNotAvailableException(this);
    }

    _events.add(PromptEntered(text, input));
    entries.increment();
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
