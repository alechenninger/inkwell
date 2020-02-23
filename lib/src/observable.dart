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

  const Observed();

  const factory Observed.always(T value) = _AlwaysObserved<T>;

  Stream<T> get _onChange;

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

@deprecated // may be no longer needed since merge now acts like this anyway
T Function(U, S) latest<T, U, S>(T Function(U, S) mapper) {
  U latestU;
  S latestS;

  return (U u, S s) {
    latestU = u ?? latestU;
    latestS = s ?? latestS;

    return mapper(latestU, latestS);
  };
}

class _AlwaysObserved<T> extends Observed<T> {
  final T value;

  const _AlwaysObserved(this.value);

  @override
  Observed<U> map<U>(U Function(T) mapper) {
    return _AlwaysObserved(mapper(value));
  }

  @override
  Observed<U> merge<U, S>(Observed<S> other, U Function(T, S) mapper) {
    return other.map((s) => mapper(value, s));
  }

  @override
  Stream<Change<T>> get onChange => Stream.empty();

  @override
  Stream<T> get _onChange => Stream.empty();
}

class _ObservableOfImmutable<T> extends Observable<T> {
  T _currentValue;
  T get value => _currentValue;
//  Stream<T> get mapTest => _changes;

  final _changes = _EventStream<Change<T>>();
  Stream<Change<T>> get onChange => _changes;

  @override
  Stream<T> get _onChange => _changes.synchronous.map((c) => c.newValue);

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
      [U Function(T, S) merger,
      U Function(T) mapFirst,
      U Function(S) mapSecond]) {
    // TODO: parameters, defaults and all that kind of complex. this okay?
    merger = merger ?? (t, u) => t ?? u;

    var thisMapped =
        _MappedObservable(_currentValue, (x) => Merged<T, S>(x, other.value));
    _mapped.add(thisMapped);

    var otherMapped = other.map((x) => Merged<T, S>(_currentValue, x));

    return _MergedObservable3(thisMapped, otherMapped, merger);
  }

  Observed<U> merge1<U, S>(Observed<S> other, U Function(T, S) mapper) {
    return _MergedObservable2(this, other, mapper);
  }

  void close() {
    _changes._done();
  }

  bool get isClosed => _changes._isDone;
}

class Merged<T, U> {
  final T t;
  final U u;

  Merged(this.t, this.u);

  @override
  String toString() {
    return 'Merged{t: $t, u: $u}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Merged &&
          runtimeType == other.runtimeType &&
          t == other.t &&
          u == other.u;

  @override
  int get hashCode => t.hashCode ^ u.hashCode;
}

class _MergedObservable3<T, U, S> extends Observed<T> {
  final Observed<Merged<U, S>> _first;
  final Observed<Merged<U, S>> _second;
  final T Function(U, S) _merger;
  T _initialValue;

  _MergedObservable3(this._first, this._second, this._merger) {
    _initialValue = value;
  }

  @override
  Observed<V> map<V>(V Function(T) mapper) {

  }

  @override
  Stream<Change<T>> get onChange => _first.onChange
      .mergeWith([_second.onChange])
      .map((c) => Change(_merger(c.newValue.t, c.newValue.u)))
      .skipWhile((c) => c.newValue == _initialValue)
      .distinct();

  @override
  T get value => _merger(_first.value.t, _second.value.u);

  @override
  Observed<U> merge<U, S>(Observed<S> other, U Function(T, S) mapper) {
    throw UnimplementedError();
  }

  @override
  // TODO: implement mapTest
  Stream<T> get _onChange => null;
}

class _StreamMappedObservable<T, U> extends Observed<T> {
  @override
  Observed<U> map<U>(U Function(T) mapper) {
    // TODO: implement map
    return null;
  }

  @override
  // TODO: implement mapTest
  Stream<T> get _onChange => null;

  @override
  Observed<U> merge<U, S>(Observed<S> other, U Function(T, S) mapper) {
    // TODO: implement merge
    return null;
  }

  @override
  // TODO: implement onChange
  Stream<Change<T>> get onChange => null;

  @override
  // TODO: implement value
  T get value => null;

}

class _MergedObservable2<T, U, S> extends Observed<T> {
  final Observed<U> _first;
  final Observed<S> _second;
  final T Function(U, S) _mapper;
  Observable<T> _observable;

  _MergedObservable2(this._first, this._second, this._mapper) {
    _observable = Observable.ofImmutable(_mapper(_first.value, _second.value));

    _first._onChange.map((c) => Change(_mapper(c, _second.value))).mergeWith([
      _second._onChange.map((c) => Change(_mapper(_first.value, c)))
    ]).forEach((c) => _observable.value = c.newValue);
  }

  @override
  Observed<U> map<U>(U Function(T) mapper) {
    // TODO: implement map
    return null;
  }

  @override
  Observed<U> merge<U, S>(Observed<S> other, U Function(T, S) mapper) {
    // TODO: implement merge
    return null;
  }

  @override
  Stream<Change<T>> get onChange => _observable.onChange;

  @override
  // TODO: implement value
  T get value => _observable.value;

  @override
  // TODO: implement mapTest
  Stream<T> get _onChange => null;
}

class _MergedObservable<T> extends Observed<T> {
  final Observed<T> _first;
  final Observed<T> _second;
  final T Function() _currentValue;

  _MergedObservable(this._first, this._second, this._currentValue);

  @override
  Observed<U> map<U>(U Function(T) mapper) {
    var first = _first.map(mapper);
    var second = _second.map(mapper);
    return _MergedObservable(first, second, () => mapper(value));
  }

  @override
  Stream<Change<T>> get onChange =>
      _first.onChange.mergeWith([_second.onChange]).distinct();

  @override
  T get value => _currentValue();

  @override
  Observed<U> merge<U, S>(Observed<S> other, U Function(T, S) mapper) {
    throw UnimplementedError();
  }

  @override
  // TODO: implement mapTest
  Stream<T> get _onChange => null;
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
    throw UnimplementedError();
  }

  @override
  // TODO: implement mapTest
  Stream<T> get _onChange => _changes.synchronous.map((c) => c.newValue);
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
