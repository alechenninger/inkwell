// Copyright (c) 2016, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august;

// TODO: Interface will change if type is mutable
abstract class Observable<T> {
  /// The current value being observed.
  T get value;

  Stream<StateChangeEvent<T>> get onChange;

  /// Create an `Observable` of an immutable _value_, like a primitive type. The
  /// reference is mutable, so the property is changeable, but each assigned
  /// value should be immutable.
  ///
  /// For mutable values like [List]s, there is no guarantee that references to
  /// the value mutate it outside of the scope of the observable.
  factory Observable.ofImmutable(T initialValue) {
    return new _ObservableOfImmutable(initialValue);
  }

  /// Schedules a change to this value in a future.
  ///
  /// Listeners will be fired in a future thereafter.
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

class _ObservableOfImmutable<T> implements Observable<T> {
  T _currentValue;
  T get value => _currentValue;

  final _changes = new StreamController.broadcast(sync: true);
  Stream<StateChangeEvent<T>> get onChange => _changes.stream;

  _ObservableOfImmutable(this._currentValue);

  Future<StateChangeEvent<T>> set(T getNewValue(T currentValue)) async {
    var newValue = getNewValue(_currentValue);

    if (newValue == _currentValue) {
      return new StateChangeEvent(_currentValue);
    }

    _currentValue = newValue;

    return new Future(() => _changes.add(new StateChangeEvent(_currentValue)));
  }
}

class StateChangeEvent<T> {
  final T newValue;

  StateChangeEvent(this.newValue);
}
