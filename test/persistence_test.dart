import 'package:test/test.dart';
import 'package:august/august.dart';

import 'util/fake_async.dart' show FakeAsync;

void main() {
  Persistence persistence;
  InteractionManager interactionMngr;
  TestModule testModule;

  setUp(() {
    testModule = new TestModule();
    persistence = new InMemoryPersistence();
    interactionMngr = new InteractionManager(
        new Clock(), persistence, [new TestInteractor(testModule)]);
  });

  run(Function script) {
    interactionMngr.run(script);
  }

  Duration currentOffset() => interactionMngr.currentOffset;

  group("Running a script with saved interactions", () {
    test("replays saved interactions in order", () {
      var occurred = [];

      persistence.saveInteraction(
          const Duration(seconds: 1), "TestModule", "first", {});
      persistence.saveInteraction(
          const Duration(seconds: 5), "TestModule", "second", {});

      run(() {
        testModule.once("first").then((_) {
          occurred.add("first");
        });
        testModule.once("second").then((_) {
          occurred.add("second");
        });
      });

      expect(occurred, equals(["first", "second"]));
    });

    test("replays saved interactions with original offsets", () {
      var times = {};

      persistence.saveInteraction(
          const Duration(seconds: 1), "TestModule", "first", {});
      persistence.saveInteraction(
          const Duration(seconds: 5), "TestModule", "second", {});

      run(() {
        times[0] = currentOffset();
        testModule.once("first").then((_) {
          times[1] = currentOffset();
        });
        testModule.once("second").then((_) {
          times[2] = currentOffset();
        });
      });

      expect(
          times,
          equals({
            0: Duration.zero,
            1: const Duration(seconds: 1),
            2: const Duration(seconds: 5)
          }));
    });

    test("maintains remaining delays after last replayed interaction", () {
      new FakeAsync().run((async) {
        var occurred = [];

        persistence.saveInteraction(
            const Duration(seconds: 1), "TestModule", "first", {});
        persistence.saveInteraction(
            const Duration(seconds: 2), "TestModule", "some event", {});

        run(() {
          testModule.once("first").then((_) {
            occurred.add("first");
            testModule.emit("second", delay: const Duration(seconds: 3));
          });
          testModule.once("second").then((_) {
            occurred.add("second");
          });
        });

        async.elapse(const Duration(seconds: 1, milliseconds: 999));
        expect(occurred, equals(["first"]));
        async.elapse(const Duration(milliseconds: 1));
        expect(occurred, equals(["first", "second"]));
      });
    });
  });
}

class InMemoryPersistence implements Persistence {
  List _saved = [];
  List<SavedInteraction> get savedInteractions => new List.from(_saved);

  @override
  void saveInteraction(Duration offset, String moduleName, String name,
      Map<String, dynamic> parameters) {
    _saved.add(new SavedInteraction(moduleName, name, parameters, offset));
  }
}

class TestModule {
  final _ctrl = new StreamController<String>.broadcast();
  Future<String> once(String event) =>
      _ctrl.stream.where((e) => e == event).first;

  Future<String> emit(String event, {Duration delay: Duration.zero}) {
    return new Future.delayed(delay, () {
      _ctrl.add(event);
      return event;
    });
  }
}

class TestInteractor implements Interactor {
  final TestModule _module;

  TestInteractor(this._module);

  @override
  String get moduleName => "TestModule";

  @override
  void run(String action, Map<String, dynamic> parameters) {
    _module.emit(action);
  }
}
