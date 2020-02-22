// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

part of '../august.dart';

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

  /// Immediately available in the current event loop, just before onEnter and
  /// onExit events are fired.
  bool get isEntered;

  /// See [isEntered]
  bool get isNotEntered => !isEntered;

  /// Streams are synchronous broadcast streams, which means if the scope is
  /// entered before entries are listened to, the listener will _not_ get an
  /// entry event, because it already happened. You can check if a scope is
  /// currently entered using [isEntered].
  ///
  /// Listeners will be fired immediately in the same event loop.
  ///
  /// Some scopes may enter and exit multiple times.
  ///
  /// Streams should emit a done event when a scope is no longer able to be
  /// entered.
  Stream<T> get onEnter;

  //Stream<Change<bool>> get onEnter =>
  //      _observed.onChange.where((e) => e.newValue);
  //
  //  Stream<Change<bool>> get onExit =>
  //      _observed.onChange.where((e) => !e.newValue);

  /// Streams are synchronous broadcast streams, which means if the scope is
  /// exited before exits are listened to, the listener will _not_ get an exit
  /// event, because it already happened. You can check if a scope is currently
  /// entered using [isEntered].
  ///
  /// Listeners will be fired immediately in the same event loop.
  ///
  /// Some scopes may enter and exit multiple times.
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
      callIfAlreadyEntered = true}) {
    this.onEnter.listen(onEnter);
    this.onExit.listen(onExit);
    if (isEntered && callIfAlreadyEntered) {
      onEnter(null);
    }
  }

// TODO: Maybe add a convenience API for listen to onEnter + check isEntered
//  void around({onEnter(Scope<T> scope), onExit(Scope<T> scope)}) {
//    if (isEntered) onEnter(this);
//    this.onEnter.listen((_) { onEnter(this); });
//    this.onExit.listen((_) { onExit(this); });
//  }
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

// A simple scope that is entered until incremented a maximum number of times.
// TODO: consider generalizing this a bit to be able to produce scopes off of
// various counts which all share the same counter
class CountScope extends Scope<int> {
  final int max;

  final Observable<int> _count;
  Observed<bool> _asObserved;
  Observed<bool> get asObserved => _asObserved;

  bool get isEntered => _count.value < max;

  Stream<int> get onEnter =>
      _asObserved.onChange.where((c) => c.newValue).map((_) => _count.value);

  Stream<int> get onExit =>
      _asObserved.onChange.where((c) => !c.newValue).map((_) => _count.value);

  CountScope(int max)
      : max = max,
        _count = Observable.ofImmutable(0) {
    _asObserved = _count.map((c) => c < max);
  }

  void increment() {
    if (_count.value == max) {
      throw StateError('Max of $max already met, cannot increment.');
    }

    _count.value++;
  }
}

typedef GetNewValue<T> = T Function(T currentValue);
typedef Predicate = bool Function();
