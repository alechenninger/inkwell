// Copyright (c) 2016, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

part of '../august.dart';

// TODO: Interface will change if type is mutable
abstract class Observable<T> extends Observed<T> {
  Observable();

  /// Create an `Observable` of an immutable _value_, like a primitive type. The
  /// reference is mutable, so the value of this `Observable` may still change,
  /// but each assigned value should be immutable.
  ///
  /// For mutable values like [List]s, there is no guarantee that references to
  /// the value mutate it outside of the scope of the observable.
  factory Observable.ofImmutable(T initialValue) {
    return _ObservableOfImmutable<T>(initialValue);
  }

  /// Changes the current value and adds the new value as a [Change]
  /// to the [onChange] stream.
  set value(T value);

  void close();

  bool get isClosed;

  bool get isNotClosed => !isClosed;
}

abstract class Observed<T> {
  T call() => value;

  /// The current value.
  T get value;

  /// Listen to changes of this value.
  ///
  /// All values will be listened to and delivered to listeners in order they
  /// subscribed, asynchronously in a microtask.
  Stream<Change<T>> get onChange;

  /// Creates an [Observed] value as a function of this value.
  ///
  /// The computation is effective immediately when the value of this original
  /// [Observed] changes, which could mean the [mapper] function is run
  /// synchronously. As such, [mapper] should be a **pure** function; it should
  /// not cause any other side effects. Similarly, it shouldn't be a function of
  /// any other state than its input.
  Observed<U> map<U>(U Function(T) mapper);

  Observed<U> merge<U, S>(Observed<S> other, U Function(T, S) mapper);
}

T Function(U, S) latest<T, U, S>(T Function(U, S) mapper) {
  U latestU;
  S latestS;

  return (U u, S s) {
    latestU = u ?? latestU;
    latestS = s ?? latestS;

    return mapper(latestU, latestS);
  };
}

class _ObservableOfImmutable<T> extends Observable<T> {
  T _currentValue;
  T get value => _currentValue;

  final _changes = _EventStream<Change<T>>();
  Stream<Change<T>> get onChange => _changes;

  final _mapped = <_MappedObservable<dynamic, T>>[];

  _ObservableOfImmutable(this._currentValue);

  set value(T value) {
    if (value == _currentValue) {
      return;
    }

    _currentValue = value;
    // Schedule changes to this value first
    _changes._add(Change(value));
    // Then notify mapped values; this way microtasks are scheduled in an
    // intuitive order (otherwise the mapped value listeners would fire first,
    // even though their values are obviously changed after the origin value).
    _mapped.forEach((m) => m._input(value));
  }

  Observed<U> map<U>(U Function(T) mapper) {
    var answer = _MappedObservable(_currentValue, mapper);
    _mapped.add(answer);
    return answer;
  }

  Observed<U> merge<U, S>(Observed<S> other,
      [U Function(T, S) mapper,
      U Function(T) mapFirst,
      U Function(S) mapSecond]) {
    mapper = mapper ?? (t, u) => t ?? u;
    // TODO: use nulls or use current other value
    //  if nulls, we know which value has changed
    var answer = _MappedObservable(
        _currentValue, mapFirst ?? (x) => mapper(x, other.value));
    var otherMapped = other.map(mapSecond ?? (x) => mapper(_currentValue, x));
    _mapped.add(answer);
    U mapCurrentValue() {
      return mapper(_currentValue, other.value);
    }

    return _MergedObservable(answer, otherMapped, mapCurrentValue);
  }

  void close() {
    _changes._done();
  }

  bool get isClosed => _changes._isDone;
}

Or<T, U> or<T, U>(T t, U u) {
  return Or(t, u);
}

class Or<T, U> {
  final T t;
  final U u;

  Or(this.t, this.u);
}

class _MergedObservable<T> extends Observed<T> {
  final Observed<T> _first;
  final Observed<T> _second;
  final T Function() _currentValue;

  _MergedObservable(this._first, this._second, this._currentValue);

  @override
  Observed<U> map<U>(U Function(T) mapper) {
    // TODO: implement map
    return null;
  }

  @override
  Stream<Change<T>> get onChange =>
      _MergedStream(_first.onChange, _second.onChange).distinct();

  @override
  T get value => _currentValue();

  @override
  Observed<U> merge<U, S>(Observed<S> other, U Function(T, S) mapper) {
    // TODO: implement mapMerge
    return null;
  }
}

class _MappedObservable<T, U> extends Observed<T> {
  T _currentValue;
  T get value => _currentValue;

  final _changes = _EventStream<Change<T>>();
  Stream<Change<T>> get onChange => _changes;

  final T Function(U) _mapper;

  final _mapped = <_MappedObservable<dynamic, T>>[];

  _MappedObservable(U input, this._mapper) {
    _input(input);
  }

  void _input(U input) {
    var newValue = _mapper(input);
    if (newValue == _currentValue) {
      return;
    }
    _currentValue = newValue;
    _changes._add(Change(_currentValue));
    _mapped.forEach((m) => m._input(value));
  }

  Observed<V> map<V>(V Function(T) mapper) {
    var answer = _MappedObservable(_currentValue, mapper);
    _mapped.add(answer);
    return answer;
  }

  @override
  Observed<U> merge<U, S>(Observed<S> other, U Function(T, S) mapper) {
    // TODO: implement mapMerge
    return null;
  }
}

class Change<T> extends Event {
  // TODO: consider adding old value
  final T newValue;

  Change(this.newValue);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Change && newValue == other.newValue;

  @override
  int get hashCode => newValue.hashCode;

  @override
  String toString() {
    return 'StateChangeEvent{newValue: $newValue}';
  }
}
