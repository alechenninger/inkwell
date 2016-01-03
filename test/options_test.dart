import 'package:test/test.dart';
import 'package:august/august.dart';
import 'package:august/options.dart';
import 'package:quiver/time.dart';

main() {
  Run run;
  Options options;

  setUp(() {
    var clock = new Clock();
    var startTime = clock.now();

    run = new Run(() => clock.now().difference(startTime));
    options = new Options(run);
  });

  group("An Option", () {
    Option opt;

    setUp(() {
      opt = new Option("", run);
    });

    group("when made available", () {
      test("emits AddOptionsEvent", () {
        opt.available(const Always());
        expect(run.once((e) => e is AddOptionEvent), completes);
      });

      test("is not immediately available", () {
        opt.available(const Always());
        expect(opt.isAvailable, isFalse);
      });

      test("is visibly available to availability listeners", () async {
        opt.available(const Always());
        await opt.availability.onEnter.first;
        expect(opt.isAvailable, isTrue);
      });

      test("emits AddOptionEvent in future after updating isAvailable",
          () async {
        opt.available(const Always());
        var order = [];
        new Future(() => order.add("future isAvailable: ${opt.isAvailable}"));
        await run.once((e) => e is AddOptionEvent).then(
            (e) => order.add("event listener isAvailable: ${opt.isAvailable}"));

        expect(
            order,
            equals([
              "future isAvailable: true",
              "event listener isAvailable: true"
            ]));
      });

      test("fires availability listeners from observable property change",
          () async {
        opt.available(const Always());
        var order = [];
        run
            .once((e) => e is AddOptionEvent)
            .then((e) => order.add("AddOptionEvent"));
        await opt.availability.onEnter.first
            .then((e) => order.add("availability"));

        expect(order, equals(["AddOptionEvent", "availability"]));
      });

      // What happens with scoped of observable:
      // 1. scope assign; assignment queued in future
      // 2. future runs, assigns scope to scoped value.
      // immediately fires listeners if assigned scope is already in scope.
      // listeners set observable property, actual mutation is queued in future
      // 3. future runs, changes property state, queues future to trigger
      // listeners to this prop change.
      // 4. future runs, fires all listeners to prop change.
      // this includes availability listeners.

      // What happens with scoped:
      // 1. scope assign; assignment queud in future
      // 2. future runs, assigns scope to scoped value.
      // immediately fire listeners if assigned scope is already in scope.
      // listener sets property, queues listeners to this change in future
      // (via AddOptionEvent)
      // 3. future runs, fires all listeners to AddOptionEvent

      // If we changed scope's scope style:
      // 1. scope assign; assignment queued in future
      // 2. future runs, assigns scope to scoped value.
      // immediately fire listeners if assigned scope is already in scope.
      // listener returns property. scoped queues listeners to this change in
      // future
      // 3. future runs, fires all listeners to availability change

      group("via scope onEnter listener", () {
        SettableScope customScope;

        setUp(() {
          customScope = new SettableScope.notEntered();
          opt.available(customScope);
        });

        test("updates isAvailable in future", () {
          customScope.enter(null);
          expect(opt.isAvailable, isFalse);
          return new Future(() => expect(opt.isAvailable, isTrue));
        });

        test("fires scope listeners after AddOptionEvent", () async {
          var order = [];
          run
              .once((e) => e is AddOptionEvent)
              .then((e) => order.add("AddOptionEvent"));
          var availability = opt.availability.onEnter.first
              .then((e) => order.add("availability"));

          customScope.enter(null);

          await availability;

          expect(order, equals(["AddOptionEvent", "availability"]));
        });
      });
    }, timeout: const Timeout(const Duration(milliseconds: 100)));
  });
}
