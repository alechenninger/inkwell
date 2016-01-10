// Copyright (c) 2016, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august;

// TODO: Interface will change if type is mutable
abstract class Observable<T> {
  /// The current value being observed. Will not change in the current event
  /// loop.
  T get value;

  /// The value that will be visible after all events are handled in the current
  /// event queue.
  T get nextValue;

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
  /// [onChange] listeners will be fired synchronously, immediately thereafter.
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
  T _nextValue;
  T get nextValue => _nextValue;

  final _changes = new StreamController.broadcast(sync: true);
  Stream<StateChangeEvent<T>> get onChange => _changes.stream;

  _ObservableOfImmutable(this._currentValue) {
    _nextValue = _currentValue;
  }

  Future<StateChangeEvent<T>> set(T getNewValue(T currentValue)) {
    _nextValue = getNewValue(_nextValue);

    return new Future(() {
      var newValue = getNewValue(_currentValue);

      if (newValue == _currentValue) {
        return null;
      }

      _currentValue = newValue;

      var event = new StateChangeEvent(_currentValue);

      _changes.add(event);

      return event;
    });
  }
}

class StateChangeEvent<T> {
  final T newValue;

  StateChangeEvent(this.newValue);
}
