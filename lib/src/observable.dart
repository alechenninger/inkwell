// Copyright (c) 2016, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august;

// TODO: Interface will change if type is mutable
abstract class Observable<T> extends Observed<T> {
  Observable() {}

  /// Create an `Observable` of an immutable _value_, like a primitive type. The
  /// reference is mutable, so the value of this `Observable` may still change,
  /// but each assigned value should be immutable.
  ///
  /// For mutable values like [List]s, there is no guarantee that references to
  /// the value mutate it outside of the scope of the observable.
  factory Observable.ofImmutable(T initialValue, {owner}) {
    return new _ObservableOfImmutable<T>(initialValue, owner);
  }

  /// Schedules a change of the observed value to the result of the provided
  /// function in a future.
  ///
  /// [onChange] listeners will be fired synchronously in the same future,
  /// immediately after the value is changed.
  ///
  /// Returned future completes once all listeners are fired.
  ///
  /// No listeners are fired if the new value is `==` to the old value.
  ///
  /// The [getNewValue] function is passed an instance of the current value. _It
  /// should not mutate this value in the listener_ but return a new instance to
  /// be used.
  Future<StateChangeEvent<T>> set(T getNewValue(T currentValue));
}

abstract class Observed<T> {
  T call() => value;

  /// The current value being observed. Will not change in the current event
  /// loop.
  T get value;

  /// The value that will be visible after all events are handled in the current
  /// event queue.
  T get nextValue;

  /// Fired synchronously in the same event loop as the observed value change,
  /// immediately after the value change.
  Stream<StateChangeEvent<T>> get onChange;
}

class _ObservableOfImmutable<T> extends Observable<T> {
  T _currentValue;
  T get value => _currentValue;
  T _nextValue;
  T get nextValue => _nextValue;

  final _owner;
  final _changes =
      new StreamController<StateChangeEvent<T>>.broadcast(sync: true);
  Stream<StateChangeEvent<T>> get onChange => _changes.stream;

  _ObservableOfImmutable(this._currentValue, this._owner) {
    _nextValue = _currentValue;
  }

  Future<StateChangeEvent<T>> set(T getNewValue(T currentValue)) {
    _nextValue = getNewValue(_nextValue);

    return new Future(() {
      var newValue = getNewValue(_currentValue);

      if (newValue == _currentValue) {
        return null; // TODO probably bad idea
      }

      _currentValue = newValue;

      var event = new StateChangeEvent<T>(_currentValue, _owner);

      _changes.add(event);

      return event;
    });
  }
}

class StateChangeEvent<T> {
  // TODO consider parameterizing type of owner
  final dynamic owner;
  final T newValue;

  StateChangeEvent(this.newValue, this.owner);
}
