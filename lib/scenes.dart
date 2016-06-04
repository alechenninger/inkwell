import 'package:august/august.dart';

class Scenes {
  final _newScenes = new StreamController<Scope>.broadcast(sync: true);
  SceneFactory _sceneFactory;

  Scenes() {
    _sceneFactory = new SceneFactory._(this);
  }

  SceneFactory get begin => _sceneFactory;

  Stream<Scope> get onBegin => _newScenes.stream;
}

class SceneFactory {
  final Scenes _scenes;

  SceneFactory._(this._scenes);

  /// Begins a new, non-reoccuring scene when the returned [Future] completes.
  ///
  /// Once a non-reoccurring scene exits it will never be entered again.
  Future<Scene> once() async {
    return _init(new Scene._(_untilNextScene));
  }

  /// Begins a new, reenterable scene when the returned [Future] completes.
  ///
  /// A reenterable scene may begin and end a number of times before it is
  /// closed.
  Future<ReenterableScene> reenterable() async {
    return _init(new ReenterableScene._(_scenes));
  }

  Scope/*=T*/ _init/*<T extends Scope>*/(Scope/*=T*/ scene) {
    _scenes._newScenes.add(scene);
    return scene;
  }

  Scope<Scene> get _untilNextScene =>
      // Exit and close as soon as there is a begin event.
      new ListeningScope.entered(_scenes.onBegin.skip(1),
          exitWhen: (scene) => true, closeWhen: (scene) => true);
}

class Scene extends Scope {
  final Scope _scope;

  Scene._(this._scope);

  @override
  bool get isEntered => _scope.isEntered;

  @override
  Stream get onEnter => _scope.onEnter;

  @override
  Stream get onExit => _scope.onExit;
}

class ReenterableScene extends Scope<ReenterableScene> {
  final Scenes _scenes;
  final _scope = new SettableScope<ReenterableScene>.entered();
  var _isDone = false;

  ReenterableScene._(this._scenes) {
    _scenes.onBegin.listen((scene) {
      if (scene == this) {
        return;
      }

      if (_scope.isNotClosed) {
        _scope.exit(this);

        if (_isDone) {
          _scope.close();
        }
      }
    });
  }

  /// Fails if the scene is already [done].
  Future<ReenterableScene> reenter() async {
    if (_isDone) {
      throw new StateError("Reenterable scene is done; cannot reenter.");
    }

    _scope.enter(this);
    _scenes._newScenes.add(this);

    return this;
  }

  void done() {
    _isDone = true;
    if (_scope.isNotEntered) {
      _scope.close();
    }
  }

  @override
  bool get isEntered => _scope.isEntered;

  @override
  Stream<ReenterableScene> get onEnter => _scope.onEnter;

  @override
  Stream<ReenterableScene> get onExit => _scope.onExit;
}
