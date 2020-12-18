// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source

// is governed by a BSD-style license that can be found in the LICENSE file.

library august.dialog;

import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:meta/meta.dart';

import 'august.dart';
import 'modules.dart';
import 'src/event_stream.dart';

part 'dialog.g.dart';

@SerializersFor([
  UseReply,
  ReplyKey,
  ReplyAvailable,
  ReplyUnavailable,
  Replied,
  SpeechKey,
  SpeechAvailable,
  SpeechUnavailable
])
final Serializers dialogSerializers = _$dialogSerializers;

class Dialog extends StoryModule {
  final _speech = ScopedElements<Speech, SpeechKey>();
  final GetScope _default;

  Dialog({GetScope defaultScope = getAlways}) : _default = defaultScope;

  Serializers get serializers => dialogSerializers;
  Stream<Event> get events => _speech.events;

  // TODO: figure out defaults
  // TODO: markup should probably be a first class thing?
  //       as in: ui.text('...')
  //       - This allows markup to be up to UI implementation
  //       - UI can also then handle localization
  //       - UI can handle complex elements (say if we want a portrait, or
  //         presentation control like alignment, style, or effects, etc.)
  //       - We'd like scripts to be decoupled from UI implementation, but
  //         interfaces can satisfy this concern.
  //       - On the other hand, we could consider markup to be Dialog specific
  //         here, not UI specific. Then UI decides what to do with the module.
  //         I guess this is what the current architecture is.
  Speech narrate(String markup, {Scope scope}) {
    return add(markup, scope: scope);
  }

  // TODO: figure out default
  //  This might be figured out now...
  Speech add(String markup,
      {String speaker, String target, Scope<dynamic> scope}) {
    scope = scope ?? _default();

    var speech = _speech.add(
        (events) => Speech(events, markup, scope, speaker, target),
        (s) => s.availability,
        (s) => s._key);

    return speech;
  }

  Voice voice({String name}) => Voice(name, this);
}

abstract class Speaks {
  Speech say(String markup, {String target, Scope scope});
}

class Voice implements Speaks {
  String name;

  final Dialog _dialog;

  Voice(this.name, this._dialog);

  Speech say(String markup, {String target, Scope scope}) =>
      _dialog.add(markup, speaker: name, target: target, scope: scope);
}

abstract class SpeechKey implements Built<SpeechKey, SpeechKeyBuilder> {
  static Serializer<SpeechKey> get serializer => _$speechKeySerializer;

  String get markup;
  @nullable
  String get speaker;

  factory SpeechKey({@required String markup, String speaker}) =>
      _$SpeechKey._(markup: markup, speaker: speaker);
  SpeechKey._();
}

class Speech extends StoryElement with Available {
  final String _markup;
  final Scope _scope;
  final String _speaker;
  final String _target;
  final SpeechKey _key;

  final EventStream<Event> _events;
  Stream<Event> get events => _events;

  Scope get availability => _scope;

  final _replies = ScopedElements<Reply, ReplyKey>();

  /// Lazily initialized scope which all replies share, making them mutually
  /// exclusive by default.
  // TODO: Support non mutually exclusive replies?
  CountScope _replyUses;

  // TODO: Support target / speaker of types other than String
  // Imagine thumbnails, for example
  // 'Displayable' type of some kind?
  Speech(this._events, this._markup, this._scope, this._speaker, this._target)
      : _key = SpeechKey(speaker: _speaker, markup: _markup) {
    _events.includeStoryElement(_replies);
    publishAvailability(_events,
        onEnter: () => SpeechAvailable.fromSpeech(this),
        onExit: () => SpeechUnavailable.fromSpeech(this));
  }

  Reply addReply(String markup, {Scope available = const Always()}) {
    _replyUses ??= CountScope(1);

    var reply = _replies.add(
      (events) => Reply(events, this, markup, _replyUses, available),
      (r) => r.availability,
      (r) => r._key,
    );

    return reply;
  }
}

abstract class ReplyKey implements Built<ReplyKey, ReplyKeyBuilder> {
  static Serializer<ReplyKey> get serializer => _$replyKeySerializer;
  SpeechKey get speech;
  String get markup;

  factory ReplyKey(SpeechKey speech, String markup) =>
      _$ReplyKey._(speech: speech, markup: markup);
  ReplyKey._();
}

class Reply extends LimitedUseElement<Reply, Replied> {
  final Speech speech;

  final String _markup;
  final ReplyKey _key;

  Reply(EventStream<Event> events, this.speech, this._markup, CountScope uses,
      Scope available)
      : _key = ReplyKey(speech._key, _markup),
        super(
            uses: uses,
            available: available,
            events: events,
            use: (r) => Replied(r._key),
            unavailableUse: (r) => ReplyNotAvailableException(r),
            onAvailable: (r) => ReplyAvailable(r.speech._key, r._markup),
            onUnavailable: (r) => ReplyUnavailable(r._key));
}

abstract class UseReply
    with Action<Dialog>
    implements Built<UseReply, UseReplyBuilder> {
  static Serializer<UseReply> get serializer => _$useReplySerializer;

  ReplyKey get reply;

  factory UseReply(ReplyKey key) => _$UseReply._(reply: key);
  UseReply._();

  void run(Dialog dialog) {
    var matchedSpeech = dialog._speech.available[reply.speech];

    if (matchedSpeech == null) {
      throw StateError('No matching available speech found for reply: '
          '${reply.speech}');
    }

    var matchedReply = matchedSpeech._replies.available[reply];

    if (matchedReply == null) {
      throw StateError('No matching available replies found for reply: '
          '$reply');
    }

    matchedReply.use();
  }
}

class ReplyNotAvailableException implements Exception {
  final Reply reply;

  ReplyNotAvailableException(this.reply);
}

abstract class SpeechAvailable
    with Event
    implements Built<SpeechAvailable, SpeechAvailableBuilder> {
  static Serializer<SpeechAvailable> get serializer =>
      _$speechAvailableSerializer;
  @nullable
  String get speaker;
  String get markup;
  @nullable
  String get target;
  SpeechKey get key => SpeechKey(markup: markup, speaker: speaker);

  factory SpeechAvailable.fromSpeech(Speech s) =>
      SpeechAvailable(s._speaker, s._markup, s._target);

  factory SpeechAvailable(String speaker, String markup, String target) =>
      _$SpeechAvailable._(speaker: speaker, markup: markup, target: target);
  SpeechAvailable._();
}

abstract class SpeechUnavailable
    with Event
    implements Built<SpeechUnavailable, SpeechUnavailableBuilder> {
  static Serializer<SpeechUnavailable> get serializer =>
      _$speechUnavailableSerializer;

  SpeechKey get key;

  factory SpeechUnavailable.fromSpeech(Speech s) => SpeechUnavailable(s._key);
  factory SpeechUnavailable(SpeechKey key) => _$SpeechUnavailable._(key: key);
  SpeechUnavailable._();
}

abstract class ReplyAvailable
    with Event
    implements Built<ReplyAvailable, ReplyAvailableBuilder> {
  static Serializer<ReplyAvailable> get serializer =>
      _$replyAvailableSerializer;
  SpeechKey get speech;
  String get markup;
  ReplyKey get key => ReplyKey(speech, markup);

  factory ReplyAvailable(SpeechKey speech, String markup) =>
      _$ReplyAvailable._(speech: speech, markup: markup);
  ReplyAvailable._();
}

abstract class ReplyUnavailable
    with Event
    implements Built<ReplyUnavailable, ReplyUnavailableBuilder> {
  static Serializer<ReplyUnavailable> get serializer =>
      _$replyUnavailableSerializer;

  ReplyKey get reply;

  factory ReplyUnavailable(ReplyKey key) => _$ReplyUnavailable._(reply: key);
  ReplyUnavailable._();
}

abstract class Replied with Event implements Built<Replied, RepliedBuilder> {
  static Serializer<Replied> get serializer => _$repliedSerializer;

  ReplyKey get reply;

  factory Replied(ReplyKey reply) => _$Replied._(reply: reply);
  Replied._();
}
