// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:august/src/scoped_object.dart';

import 'august.dart';
import 'input.dart';
import 'src/events.dart';
import 'src/scope.dart';
import 'src/persistence.dart';

class Options {
  final _availableOptCtrl = StreamController<Option>(sync: true);
  final _options = ScopedEmitters<Option, String>();
  final GetScope _default;

  Options({GetScope defaultScope = getAlways}) : _default = defaultScope;

  Stream<Option> get _onOptionAvailable => _availableOptCtrl.stream;

  Option oneTime(String text, {Scope available, CountScope exclusiveWith}) {
    return limitedUse(text,
        available: available,
        exclusiveWith: exclusiveWith?.withRemaining(1) ?? CountScope(1));
  }

  /// Creates a new limited use option that can be used while [available] and
  /// has remaining uses determined by [exclusiveWith].
  Option limitedUse(String text, {Scope available, CountScope exclusiveWith}) {
    var option = Option._(text,
        uses: exclusiveWith ?? CountScope(1),
        available: available ?? _default());

    _options.add(option, option.availability,
        key: option.text,
        onAvailable: () => OptionAvailable(option.text),
        onUnavailable: () => OptionUnavailable(option.text));

    return option;
  }
}

class Option extends Emitter {
  final String text;

  int get maxUses => uses.max;
  int get useCount => uses.count;

  Scope _available;

  bool get isAvailable => _available.isEntered;

  /// A scope that is entered whenever this option is available.
  Scope get availability => _available;

  // TODO: Consider simply Stream<Option>
  Stream<OptionUsed> get onUse => _onUse.stream;

  final CountScope uses;
  final _onUse = Events<OptionUsed>();

  Stream<Event> get events => _onUse.stream;

  Option._(this.text, {CountScope uses, Scope available = always})
      : uses = uses ?? CountScope(1) {
    _available = available.and(this.uses);
  }

  /// Schedules option to be used at the end of the current event queue.
  ///
  /// The return future completes with success when the option is used and all
  /// listeners receive it. It completes with an error if the option is not
  /// available to be used.
  Future<OptionUsed> use() async {
    // Wait to check isAvailable until option actually about to be used
    var e = await _onUse.event(() {
      if (!isAvailable) {
        throw OptionNotAvailableException(this);
      }

      return OptionUsed(text);
    });

    // This could be left out of a core implementation, and "uses" could be
    // implemented as an extension by listening to the use() and a modified
    // availability scope, as is done here.
    uses.increment();

    return e;
  }

  String toString() => 'Option{'
      "text='$text',"
      'allowedUseCount=$maxUses,'
      'useCount=$useCount'
      '}';
}

class UseOption implements Action<Options> {
  final String moduleName = '$Options';
  final String name = '$UseOption';
  final Map<String, dynamic> parameters;

  UseOption(String option) : parameters = {'text': option};

  void run(Options options) {
    if (!parameters.containsKey('text')) {
      throw ArgumentError.value(
          parameters,
          'parameters',
          'Expected json to contain '
              '"text" field.');
    }

    var text = parameters['text'];
    var found = options._options.available[text];

    if (found == null) {
      throw StateError('No option found from text "$text".');
    }

    found.use();
  }
}

class OptionUsed extends Event {
  final String option;

  OptionUsed(this.option);
}

class OptionAvailable extends Event {
  final String option;

  OptionAvailable(this.option);
}

class OptionUnavailable extends Event {
  final String option;

  OptionUnavailable(this.option);
}

// Not sure if this should be error or exception
// Depends on context, so probably exception
class OptionNotAvailableException implements Exception {
  final Option option;

  OptionNotAvailableException(this.option);
}
