// Copyright (c) 2016, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'events.dart';

import 'package:rxdart/rxdart.dart';

export 'dart:async';

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

  /// A synchronous stream of values. **Use with care.**
  Stream<T> get values;
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
  Stream<T> get values => Stream.empty();
}

class _ObservableOfImmutable<T> extends Observable<T> {
  T _currentValue;
  T get value => _currentValue;

  final _changes = EventStream<Change<T>>();
  Stream<Change<T>> get onChange => _changes;

  @override
  Stream<T> get values => _changes.asSynchronousStream.map((c) => c.newValue);

  _ObservableOfImmutable(this._currentValue);

  set value(T value) {
    if (value == _currentValue) {
      return;
    }

    _currentValue = value;
    _changes.add(Change(value));
  }

  Observed<U> map<U>(U Function(T) mapper) {
    var mapped = Observable.ofImmutable(mapper(value));
    values.listen((v) => mapped.value = mapper(v), onDone: mapped.close);
    return mapped;
  }

  Observed<U> merge<U, S>(Observed<S> other, U Function(T, S) merger) {
    var merged = Observable.ofImmutable(merger(value, other.value));

    values
        .map((c) => merger(c, other.value))
        .mergeWith([other.values.map((c) => merger(value, c))]).listen(
            (e) => merged.value = e,
            onDone: merged.close);

    return merged;
  }

  void close() {
    _changes.done();
  }

  bool get isClosed => _changes.isDone;
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
