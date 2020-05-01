// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'observable.dart';

export 'dart:async';

export 'observable.dart';

typedef GetScope = Scope Function();

Always getAlways() {
  return always;
}

/// Defines a period of time by enter and exit event streams.
///
/// `Scope`s are used to control availability or state of other story objects
/// like options or dialog.
///
/// Any boundaries of particular events may be defined as a `Scope`. For
/// example, boundaries can be defined by specific date times or any predicate
/// on story state like location or inventory. `Scope`s are very flexible and
/// intended as a core building block for arbitrarily complicated state rules.
// TODO: Rethink parameterized type usage here
abstract class Scope<T> {
  const Scope();

  /// Whether or not the scope is currently entered.
  bool get isEntered;

  /// See [isEntered]
  bool get isNotEntered => !isEntered;

  /// Streams are broadcast streams, which means if the scope is entered before
  /// entries are listened to, the listener will _not_ get an entry event,
  /// because it already happened. You can check if a scope is currently entered
  /// using [isEntered].
  ///
  /// Listeners will be fired in a microtask.
  ///
  /// Some scopes may enter and exit multiple times, although you will never
  /// get multiple exit or enter events in a row. Events are only published when
  /// the state has changed from entered to exited or vice versa.
  ///
  /// Streams should emit a done event when a scope is no longer able to be
  /// entered.
  Stream<T> get onEnter;

  //Stream<Change<bool>> get onEnter =>
  //      _observed.onChange.where((e) => e.newValue);
  //
  //  Stream<Change<bool>> get onExit =>
  //      _observed.onChange.where((e) => !e.newValue);

  /// Streams are broadcast streams, which means if the scope is exited before
  /// exits are listened to, the listener will _not_ get an exit event, because
  /// it already happened. You can check if a scope is currently entered using
  /// [isEntered].
  ///
  /// Listeners will be fired in a microtask.
  ///
  /// Some scopes may enter and exit multiple times, although you will never
  /// get multiple exit or enter events in a row. Events are only published when
  /// the state has changed from entered to exited or vice versa.
  ///
  /// Streams should emit a done event when a scope is no longer able to be
  /// exited.
  Stream<T> get onExit;

  Observed<bool> get asObserved;

//  Scope<T> where(bool Function() isTrue) {
//    return PredicatedScope(isTrue, this);
//  }

  Scope and(Scope scope) {
    return merge(scope, (s1, s2) => s1 && s2);
  }

  Scope merge(Scope scope, bool Function(bool, bool) merger) {
    return ScopeFromObserved(asObserved.merge(scope.asObserved, merger));
  }

  /// Produces a [Scope] as a function of this scope's entered state.
  ///
  /// A [mapper] function accepts scope entries an exits as true and false
  /// input respectively, returning a bool to indicate whether the produced
  /// scope should be entered.
  ///
  /// The produced scope's state is updated synchronously as this scope changes.
  Scope map(bool Function(bool) mapper) {
    return ScopeFromObserved(asObserved.map(mapper));
  }

  /// Shorthand to listening to [onEnter] and [onExit] streams of the scope
  /// with the given [onEnter] and [onExit] callbacks.
  ///
  /// Calls [onEnter] with `null` if the scope is already entered and
  /// [callIfAlreadyEntered] is `true`.
  void listen(
      {void Function(T) onEnter,
      void Function(T) onExit,
      bool callIfAlreadyEntered = true}) {
    this.onEnter.listen(onEnter);
    this.onExit.listen(onExit);
    if (isEntered && callIfAlreadyEntered) {
      onEnter(null);
    }
  }
}

const always = Always();
const never = Never();

class Always extends Scope<void> {
  final isEntered = true;
  final isNotEntered = false;
  final onEnter = const Stream<Null>.empty();
  final onExit = const Stream<Null>.empty();
  final Observed<bool> asObserved = const Observed.always(true);

  const Always();

  Scope and(Scope scope) => scope;

  Scope<void> where(bool Function() isTrue) => isTrue() ? this : const Never();
}

class Never extends Scope<void> {
  final isEntered = false;
  final isNotEntered = true;
  final onEnter = const Stream<Null>.empty();
  final onExit = const Stream<Null>.empty();
  final Observed<bool> asObserved = const Observed.always(false);

  const Never();

  Scope and(Scope scope) => this;

  Scope<void> where(bool Function() isTrue) => this;
}

class ScopeFromObserved extends Scope<Change<bool>> {
  final Observed<bool> _observed;
  Observed<bool> get asObserved => _observed;

  ScopeFromObserved(this._observed);

  bool get isEntered => _observed.value;

  Stream<Change<bool>> get onEnter =>
      _observed.onChange.where((e) => e.newValue);

  Stream<Change<bool>> get onExit =>
      _observed.onChange.where((e) => !e.newValue);
}

class SettableScope extends Scope<Change<bool>> {
  final Observable<bool> _scope;
  Observed<bool> get asObserved => _scope;

  SettableScope._(bool isEntered) : _scope = Observable.ofImmutable(isEntered);

  SettableScope.entered() : this._(true);

  SettableScope.notEntered() : this._(false);

  void enter() {
    _scope.value = true;
  }

  void exit() {
    _scope.value = false;
  }

  void close() {
    _scope.close();
  }

  bool get isClosed => _scope.isClosed;

  bool get isNotClosed => !isClosed;

  bool get isEntered => _scope.value;

  Stream<Change<bool>> get onEnter => _scope.onChange.where((e) => e.newValue);

  Stream<Change<bool>> get onExit => _scope.onChange.where((e) => !e.newValue);
}

/// A simple scope that is entered until incremented a maximum number of times.
class CountScope extends Scope<int> {
  final int max;

  final Observable<int> _count;
  Observed<bool> _asObserved;
  Observed<bool> get asObserved => _asObserved;

  int get count => _count.value;

  bool get isEntered => _count.value < max;

  Stream<int> get onEnter =>
      _asObserved.onChange.where((c) => c.newValue).map((_) => _count.value);

  Stream<int> get onExit =>
      _asObserved.onChange.where((c) => !c.newValue).map((_) => _count.value);

  CountScope(int max, [Observable<int> count])
      : max = max,
        _count = count ?? Observable.ofImmutable(0) {
    if (max < 0) {
      throw ArgumentError.value(max, 'max', 'Max count must be non-negative.');
    }

    if (_count.value < 0) {
      throw ArgumentError.value(
          _count, 'counter', 'Count must start at 0 or greater.');
    }

    _asObserved = _count.map((c) => c < max);
  }

  /// Produces a new [CountScope] which shares the same underlying counter, but
  /// may use a different [max]. That is, multiple scopes will exist, where an
  /// an increment of any will increment all, but each scope will be exited
  /// independently depending on its own [max] value.
  CountScope withMax(int max) => CountScope(max, _count);

  /// Produces a new [CountScope] which shares the same underlying counter, but
  /// may use a different max, as defined by how many [remaining] times the
  /// counter may be incremented beyond the current number as time of call. That
  /// is, multiple scopes will exist, where an an increment of any will
  /// increment all, but each scope will be exited independently depending on
  /// its own max value.
  CountScope withRemaining(int remaining) =>
      CountScope(remaining + _count.value, _count);

  void increment() {
    // TODO: does this make sense if we keep sharing counter?
    if (_count.value >= max) {
      throw StateError('Max of $max already met (current value is '
          '${_count.value}, cannot increment.');
    }

    _count.value++;
  }
}

typedef GetNewValue<T> = T Function(T currentValue);
typedef Predicate = bool Function();

/// A scope that forwards another, possibly changing, scope.
///
/// Normally changing a scope would require change references; listeners
/// subscribed before the change would still be listening to the previous
/// stream(s). This scope and the stream pointers it returns are *stable*
/// through changes in backing scope.
class MutableScope extends Scope {
  final Observable<bool> _observable;
  StreamSubscription _current;

  void changeTo(Scope next) {
    _current?.cancel();
    _observable.value = next.isEntered;
    _current =
        next.asObserved.values.listen((val) => _observable.value = val);
  }

  MutableScope(Scope current)
      : _observable = Observable.ofImmutable(current.isEntered) {
    changeTo(current);
  }

  Observed<bool> get asObserved => _observable;

  bool get isEntered => _observable.value;

  Stream get onEnter => _observable.onChange.where((c) => c.newValue);

  Stream get onExit => _observable.onChange.where((c) => !c.newValue);
}
