// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.options;

import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

import 'august.dart';
import 'modules.dart';

part 'options.g.dart';

@SerializersFor([UseOption, OptionAvailable, OptionUnavailable])
final Serializers optionsSerializers = _$optionsSerializers;

class Options extends StoryModule {
  final _options = StoryElements<Option, String>();
  final GetScope _default;

  Options({GetScope defaultScope = getAlways}) : _default = defaultScope;

  Serializers get serializers => optionsSerializers;
  Stream<Event> get events => _options.events;

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

@SerializersFor([UseOption])
final Serializers serializers = _$serializers;

class Option extends StoryElement {
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

abstract class UseOption
    with Action<Options>
    implements Built<UseOption, UseOptionBuilder> {
  static Serializer<UseOption> get serializer => _$useOptionSerializer;

  String get option;

  factory UseOption(String option) => _$UseOption._(option: option);
  UseOption._();

  void run(Options options) {
    var found = options._options.available[option];

    if (found == null) {
      throw StateError('No option found from text "$option".');
    }

    found.use();
  }
}

abstract class OptionUsed
    with Event
    implements Built<OptionUsed, OptionUsedBuilder> {
  static Serializer<OptionUsed> get serializer => _$optionUsedSerializer;

  String get option;

  factory OptionUsed(String option) => _$OptionUsed._(option: option);
  OptionUsed._();
}

abstract class OptionAvailable
    with Event
    implements Built<OptionAvailable, OptionAvailableBuilder> {
  static Serializer<OptionAvailable> get serializer =>
      _$optionAvailableSerializer;

  String get option;

  factory OptionAvailable(String option) => _$OptionAvailable._(option: option);
  OptionAvailable._();
}

abstract class OptionUnavailable
    with Event
    implements Built<OptionUnavailable, OptionUnavailableBuilder> {
  static Serializer<OptionUnavailable> get serializer =>
      _$optionUnavailableSerializer;
  String get option;

  factory OptionUnavailable(String option) =>
      _$OptionUnavailable._(option: option);
  OptionUnavailable._();
}

// Not sure if this should be error or exception
// Depends on context, so probably exception
class OptionNotAvailableException implements Exception {
  final Option option;

  OptionNotAvailableException(this.option);
}
