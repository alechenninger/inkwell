// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

library inkwell.options;

import 'package:inkwell/src/event_stream.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

import 'inkwell.dart';
import 'inks.dart';

part 'options.g.dart';

@SerializersFor([UseOption, OptionAvailable, OptionUnavailable, OptionUsed])
final Serializers optionsSerializers = _$optionsSerializers;

class Options extends Ink {
  final _options = ScopedElements<Option, String>();
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
    var option = _options.add(
        (events) => Option._(events, text,
            uses: exclusiveWith ?? CountScope(1),
            available: available ?? _default()),
        (o) => o.availability,
        (o) => o.text);

    return option;
  }

  @override
  Future close() => _options.close();
}

class Option extends LimitedUseElement<Option, OptionUsed> {
  final String text;

  Option._(EventStream<Event> events, this.text,
      {CountScope uses, Scope available = always})
      : super(
            uses: uses,
            available: available,
            events: events,
            use: (o) => OptionUsed(text),
            unavailableUse: (o) => OptionNotAvailableException(o),
            onAvailable: (o) => OptionAvailable(o.text),
            onUnavailable: (o) => OptionUnavailable(o.text));

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

  void perform(Options options) {
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
