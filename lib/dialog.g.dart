// GENERATED CODE - DO NOT MODIFY BY HAND

part of august.dialog;

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializers _$dialogSerializers = (new Serializers().toBuilder()
      ..add(SpeechKey.serializer)
      ..add(UseReply.serializer))
    .build();
Serializer<SpeechKey> _$speechKeySerializer = new _$SpeechKeySerializer();
Serializer<UseReply> _$useReplySerializer = new _$UseReplySerializer();

class _$SpeechKeySerializer implements StructuredSerializer<SpeechKey> {
  @override
  final Iterable<Type> types = const [SpeechKey, _$SpeechKey];
  @override
  final String wireName = 'SpeechKey';

  @override
  Iterable<Object> serialize(Serializers serializers, SpeechKey object,
      {FullType specifiedType = FullType.unspecified}) {
    final result = <Object>[
      'markup',
      serializers.serialize(object.markup,
          specifiedType: const FullType(String)),
    ];
    if (object.speaker != null) {
      result
        ..add('speaker')
        ..add(serializers.serialize(object.speaker,
            specifiedType: const FullType(String)));
    }
    return result;
  }

  @override
  SpeechKey deserialize(Serializers serializers, Iterable<Object> serialized,
      {FullType specifiedType = FullType.unspecified}) {
    final result = new SpeechKeyBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current as String;
      iterator.moveNext();
      final dynamic value = iterator.current;
      switch (key) {
        case 'markup':
          result.markup = serializers.deserialize(value,
              specifiedType: const FullType(String)) as String;
          break;
        case 'speaker':
          result.speaker = serializers.deserialize(value,
              specifiedType: const FullType(String)) as String;
          break;
      }
    }

    return result.build();
  }
}

class _$UseReplySerializer implements StructuredSerializer<UseReply> {
  @override
  final Iterable<Type> types = const [UseReply, _$UseReply];
  @override
  final String wireName = 'UseReply';

  @override
  Iterable<Object> serialize(Serializers serializers, UseReply object,
      {FullType specifiedType = FullType.unspecified}) {
    final result = <Object>[
      'speech',
      serializers.serialize(object.speech,
          specifiedType: const FullType(SpeechKey)),
      'reply',
      serializers.serialize(object.reply,
          specifiedType: const FullType(String)),
    ];

    return result;
  }

  @override
  UseReply deserialize(Serializers serializers, Iterable<Object> serialized,
      {FullType specifiedType = FullType.unspecified}) {
    final result = new UseReplyBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current as String;
      iterator.moveNext();
      final dynamic value = iterator.current;
      switch (key) {
        case 'speech':
          result.speech.replace(serializers.deserialize(value,
              specifiedType: const FullType(SpeechKey)) as SpeechKey);
          break;
        case 'reply':
          result.reply = serializers.deserialize(value,
              specifiedType: const FullType(String)) as String;
          break;
      }
    }

    return result.build();
  }
}

class _$SpeechKey extends SpeechKey {
  @override
  final String markup;
  @override
  final String speaker;

  factory _$SpeechKey([void Function(SpeechKeyBuilder) updates]) =>
      (new SpeechKeyBuilder()..update(updates)).build();

  _$SpeechKey._({this.markup, this.speaker}) : super._() {
    if (markup == null) {
      throw new BuiltValueNullFieldError('SpeechKey', 'markup');
    }
  }

  @override
  SpeechKey rebuild(void Function(SpeechKeyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SpeechKeyBuilder toBuilder() => new SpeechKeyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SpeechKey &&
        markup == other.markup &&
        speaker == other.speaker;
  }

  @override
  int get hashCode {
    return $jf($jc($jc(0, markup.hashCode), speaker.hashCode));
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper('SpeechKey')
          ..add('markup', markup)
          ..add('speaker', speaker))
        .toString();
  }
}

class SpeechKeyBuilder implements Builder<SpeechKey, SpeechKeyBuilder> {
  _$SpeechKey _$v;

  String _markup;
  String get markup => _$this._markup;
  set markup(String markup) => _$this._markup = markup;

  String _speaker;
  String get speaker => _$this._speaker;
  set speaker(String speaker) => _$this._speaker = speaker;

  SpeechKeyBuilder();

  SpeechKeyBuilder get _$this {
    if (_$v != null) {
      _markup = _$v.markup;
      _speaker = _$v.speaker;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SpeechKey other) {
    if (other == null) {
      throw new ArgumentError.notNull('other');
    }
    _$v = other as _$SpeechKey;
  }

  @override
  void update(void Function(SpeechKeyBuilder) updates) {
    if (updates != null) updates(this);
  }

  @override
  _$SpeechKey build() {
    final _$result = _$v ?? new _$SpeechKey._(markup: markup, speaker: speaker);
    replace(_$result);
    return _$result;
  }
}

class _$UseReply extends UseReply {
  @override
  final SpeechKey speech;
  @override
  final String reply;

  factory _$UseReply([void Function(UseReplyBuilder) updates]) =>
      (new UseReplyBuilder()..update(updates)).build();

  _$UseReply._({this.speech, this.reply}) : super._() {
    if (speech == null) {
      throw new BuiltValueNullFieldError('UseReply', 'speech');
    }
    if (reply == null) {
      throw new BuiltValueNullFieldError('UseReply', 'reply');
    }
  }

  @override
  UseReply rebuild(void Function(UseReplyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  UseReplyBuilder toBuilder() => new UseReplyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is UseReply && speech == other.speech && reply == other.reply;
  }

  @override
  int get hashCode {
    return $jf($jc($jc(0, speech.hashCode), reply.hashCode));
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper('UseReply')
          ..add('speech', speech)
          ..add('reply', reply))
        .toString();
  }
}

class UseReplyBuilder implements Builder<UseReply, UseReplyBuilder> {
  _$UseReply _$v;

  SpeechKeyBuilder _speech;
  SpeechKeyBuilder get speech => _$this._speech ??= new SpeechKeyBuilder();
  set speech(SpeechKeyBuilder speech) => _$this._speech = speech;

  String _reply;
  String get reply => _$this._reply;
  set reply(String reply) => _$this._reply = reply;

  UseReplyBuilder();

  UseReplyBuilder get _$this {
    if (_$v != null) {
      _speech = _$v.speech?.toBuilder();
      _reply = _$v.reply;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(UseReply other) {
    if (other == null) {
      throw new ArgumentError.notNull('other');
    }
    _$v = other as _$UseReply;
  }

  @override
  void update(void Function(UseReplyBuilder) updates) {
    if (updates != null) updates(this);
  }

  @override
  _$UseReply build() {
    _$UseReply _$result;
    try {
      _$result = _$v ?? new _$UseReply._(speech: speech.build(), reply: reply);
    } catch (_) {
      String _$failedField;
      try {
        _$failedField = 'speech';
        speech.build();
      } catch (e) {
        throw new BuiltValueNestedFieldError(
            'UseReply', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: always_put_control_body_on_new_line,always_specify_types,annotate_overrides,avoid_annotating_with_dynamic,avoid_as,avoid_catches_without_on_clauses,avoid_returning_this,lines_longer_than_80_chars,omit_local_variable_types,prefer_expression_function_bodies,sort_constructors_first,test_types_in_equals,unnecessary_const,unnecessary_new
