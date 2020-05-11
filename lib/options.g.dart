// GENERATED CODE - DO NOT MODIFY BY HAND

part of august.options;

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializers _$optionsSerializers =
    (new Serializers().toBuilder()..add(UseOption.serializer)).build();
Serializers _$serializers =
    (new Serializers().toBuilder()..add(UseOption.serializer)).build();
Serializer<UseOption> _$useOptionSerializer = new _$UseOptionSerializer();

class _$UseOptionSerializer implements StructuredSerializer<UseOption> {
  @override
  final Iterable<Type> types = const [UseOption, _$UseOption];
  @override
  final String wireName = 'UseOption';

  @override
  Iterable<Object> serialize(Serializers serializers, UseOption object,
      {FullType specifiedType = FullType.unspecified}) {
    final result = <Object>[
      'option',
      serializers.serialize(object.option,
          specifiedType: const FullType(String)),
    ];

    return result;
  }

  @override
  UseOption deserialize(Serializers serializers, Iterable<Object> serialized,
      {FullType specifiedType = FullType.unspecified}) {
    final result = new UseOptionBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current as String;
      iterator.moveNext();
      final dynamic value = iterator.current;
      switch (key) {
        case 'option':
          result.option = serializers.deserialize(value,
              specifiedType: const FullType(String)) as String;
          break;
      }
    }

    return result.build();
  }
}

class _$UseOption extends UseOption {
  @override
  final String option;

  factory _$UseOption([void Function(UseOptionBuilder) updates]) =>
      (new UseOptionBuilder()..update(updates)).build();

  _$UseOption._({this.option}) : super._() {
    if (option == null) {
      throw new BuiltValueNullFieldError('UseOption', 'option');
    }
  }

  @override
  UseOption rebuild(void Function(UseOptionBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  UseOptionBuilder toBuilder() => new UseOptionBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is UseOption && option == other.option;
  }

  @override
  int get hashCode {
    return $jf($jc(0, option.hashCode));
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper('UseOption')..add('option', option))
        .toString();
  }
}

class UseOptionBuilder implements Builder<UseOption, UseOptionBuilder> {
  _$UseOption _$v;

  String _option;
  String get option => _$this._option;
  set option(String option) => _$this._option = option;

  UseOptionBuilder();

  UseOptionBuilder get _$this {
    if (_$v != null) {
      _option = _$v.option;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(UseOption other) {
    if (other == null) {
      throw new ArgumentError.notNull('other');
    }
    _$v = other as _$UseOption;
  }

  @override
  void update(void Function(UseOptionBuilder) updates) {
    if (updates != null) updates(this);
  }

  @override
  _$UseOption build() {
    final _$result = _$v ?? new _$UseOption._(option: option);
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: always_put_control_body_on_new_line,always_specify_types,annotate_overrides,avoid_annotating_with_dynamic,avoid_as,avoid_catches_without_on_clauses,avoid_returning_this,lines_longer_than_80_chars,omit_local_variable_types,prefer_expression_function_bodies,sort_constructors_first,test_types_in_equals,unnecessary_const,unnecessary_new
