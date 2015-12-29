import 'package:test/test.dart';
import 'package:august/august.dart';

import 'util/fake_async.dart' show FakeAsync;

void main() {
  var persistence;

  setUp(() {
    persistence = new InMemoryPersistence();
  });

  group("starting a script with saved events", () {
    test("triggers saved events in order", () {
      var occurred = [];

      var script = new Script("test", "1", [new TestEmitterModule()],
          (Run run, Map modules) {
        run.once("first").then((_) {
          occurred.add("first");
        });
        run.once("second").then((_) {
          occurred.add("second");
        });
      });

      persistence.saveEvent(new InterfaceEvent(
          TestEmitter, 'emit', {'alias': 'first'}, const Duration(seconds: 1)));
      persistence.saveEvent(new InterfaceEvent(TestEmitter, 'emit',
          {'alias': 'second'}, const Duration(seconds: 5)));

      start(script, persistence: persistence);

      expect(occurred, equals(["first", "second"]));
    });

    test("keeps track of play time while fast forwarding saved events", () {
      var times = {};

      var script = new Script("test", "1", [new TestEmitterModule()],
          (Run run, Map modules) {
        times[0] = run.currentPlayTime();
        run.once("first").then((_) {
          times[1] = run.currentPlayTime();
        });
        run.once("second").then((_) {
          times[2] = run.currentPlayTime();
        });
      });

      persistence.saveEvent(new InterfaceEvent(
          TestEmitter, 'emit', {'alias': 'first'}, const Duration(seconds: 1)));
      persistence.saveEvent(new InterfaceEvent(TestEmitter, 'emit',
          {'alias': 'second'}, const Duration(seconds: 5)));

      start(script, persistence: persistence);

      expect(
          times,
          equals({
            0: Duration.ZERO,
            1: const Duration(seconds: 1),
            2: const Duration(seconds: 5)
          }));
    });

    test("switches to parent zone after fast forwarding up to last saved event",
        () {
      new FakeAsync().run((async) {
        var occurred = [];

        var script = new Script("test", "1", [new TestEmitterModule()],
            (Run run, Map modules) {
          run.once("first").then((_) {
            occurred.add("first");
            run.emit("second", delay: const Duration(seconds: 3));
          });
          run.once("second").then((_) {
            occurred.add("second");
          });
        });

        persistence.saveEvent(new InterfaceEvent(TestEmitter, 'emit',
            {'alias': 'first'}, const Duration(seconds: 1)));
        persistence.saveEvent(new InterfaceEvent(TestEmitter, 'emit',
            {'alias': 'some event'}, const Duration(seconds: 2)));

        start(script, persistence: persistence);

        async.elapse(const Duration(seconds: 1, milliseconds: 999));
        expect(occurred, equals(["first"]));
        async.elapse(const Duration(milliseconds: 1));
        expect(occurred, equals(["first", "second"]));
      });
    });
  });
}

class InMemoryPersistence implements Persistence {
  List _savedEvents = [];
  List get savedEvents => new List.from(_savedEvents);
  saveEvent(InterfaceEvent e) {
    _savedEvents.add(e);
  }
}

class TestEmitterModule implements ModuleDefinition, InterfaceModuleDefinition {
  TestEmitter createModule(Run run, Map modules) => new TestEmitter(run);
  TestEmitterInterface createInterface(module, emit) =>
      new TestEmitterInterface();
  TestEmitterHandler createInterfaceHandler(TestEmitter emitter) =>
      new TestEmitterHandler(emitter);
}

class TestEmitter {
  Run _run;

  TestEmitter(this._run);

  emit(String alias) {
    _run.emit(alias);
  }
}

class TestEmitterInterface implements Interface {}

class TestEmitterHandler implements InterfaceHandler {
  TestEmitter _emitter;

  TestEmitterHandler(this._emitter);

  handle(String action, Map args) {
    if (action == "emit") {
      _emitter.emit(args['alias']);
    }
  }
}
