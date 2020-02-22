// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:august/august.dart';

import 'package:optional/optional.dart';
import 'package:pedantic/pedantic.dart';

// TODO: Probably rethink this later
class Scenes {
  /// Internally used to keep track of scene changes, to prevent multiple scenes
  /// from being in scope at once. These effects must be immediate–that is, it
  /// can never be observed that two scenes are active at once–so this is why
  /// the controller is synchronous.
  // TODO: consider using something other than stream controller her for same
  //  effect
  final _newScenes = StreamController<Scene>.broadcast(sync: true);
  Scene _current;

  Scenes() {
    _onNewScene.listen((scene) => _current = scene);
  }

  /// Creates a scene which will enter at most once, and exits as soon as
  /// another scene begins.
  ///
  /// To enter the created scene, call [Scene.enter].
  ///
  /// Accepts an optional [title] which is purely for annotation and not exposed
  /// from the scene API intentionally to discourage non-type-safe scene
  /// matching.
  Scene oneTime({String title}) => _OneTimeScene(this);

  ReentrantScene reentrant({String title}) => ReentrantScene._(this);

  Stream<Scene> get _onNewScene => _newScenes.stream;

  // TODO: If there is a "root" scene, this is not optional
  Optional<Scene> get currentScene => Optional.ofNullable(_current);
}

abstract class Scene<T extends Scene<T>> extends Scope<T> {
  Future<Scene> enter();
}

class _OneTimeScene extends Scene<_OneTimeScene> {
  final _scope = SettableScope.notEntered();
  final Scenes _scenes;
  Observed<bool> get asObserved => _scope.asObserved;

  _OneTimeScene(this._scenes);

  Future<Scene> enter() {
    return Future(() async {
      _scope.enter();
      _scenes._newScenes.add(this);
      unawaited(_scenes._onNewScene.first.then((_) {
        _scope.exit();
        _scope.close();
      }));
      return this;
    });
  }

  @override
  bool get isEntered => _scope.isEntered;

  @override
  Stream<_OneTimeScene> get onEnter => _scope.onEnter.map((_) => this);

  @override
  Stream<_OneTimeScene> get onExit => _scope.onExit.map((_) => this);
}

class ReentrantScene extends Scene<ReentrantScene> {
  final Scenes _scenes;
  final _scope = SettableScope.entered();
  var _isDone = false;

  Observed<bool> get asObserved => _scope.asObserved;

  ReentrantScene._(this._scenes) {
    _scenes._onNewScene.listen((scene) {
      if (scene == this) {
        return;
      }

      if (_scope.isNotClosed) {
        _scope.exit();

        if (_isDone) {
          _scope.close();
        }
      }
    });
  }

  void done() {
    _isDone = true;
    if (_scope.isNotEntered) {
      _scope.close();
    }
  }

  /// Returns a scope which is entered for only certain entrances of this
  /// reenterable scene.
  ///
  /// Accepts an [isEntered] function which returns true or false based on
  /// whether this entrance number should cause the scope to enter or exit.
  ///
  /// Similarly, an optional [isDone] function may be provide to finish the
  /// scope. Once this returns true, the scope will never enter again.
  // TODO: Name this function better
  // TODO: Consider adding this to SettableScope
  Scope subset(bool Function(int entranceNumber) isEntered,
      {bool Function(int entranceNumber) isDone}) {
    throw "Not implemented";
  }

  Scope get first => subset((i) => i == 1, isDone: (i) => i > 1);

  /// Fails if the scene [_isDone].
  @override
  Future<ReentrantScene> enter() {
    return Future(() async {
      if (_isDone) {
        throw StateError("Reenterable scene is done; cannot reenter.");
      }

      _scope.enter();
      _scenes._newScenes.add(this);

      return this;
    });
  }

  @override
  bool get isEntered => _scope.isEntered;

  @override
  Stream<ReentrantScene> get onEnter => _scope.onEnter.map((_) => this);

  @override
  Stream<ReentrantScene> get onExit => _scope.onExit.map((_) => this);
}
