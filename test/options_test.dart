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

      test("is visibly available to AddOptionEvent listeners", () async {
        opt.available(const Always());
        AddOptionEvent e = await run.once((e) => e is AddOptionEvent);
        expect(e.option.isAvailable, isTrue);
      });

      test("is not immediately available", () {
        opt.available(const Always());
        expect(opt.isAvailable, isFalse);
      });

      test("is not visibly available to availability listeners", () async {
        opt.available(const Always());
        await opt.availability.onEnter.first;
        expect(opt.isAvailable, isFalse);
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

      test("fires availability listeners before emitting AddOptionEvent", () async {
        opt.available(const Always());
        var order = [];
        opt.availability.onEnter.first.then((e) => order.add("availability"));
        await run.once((e) => e is AddOptionEvent).then((e) => order.add("AddOptionEvent"));

        expect(order, equals(["availability", "AddOptionEvent"]));
      });

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

        test("fires scope listeners immediately", () {
          var completed = false;
          opt.availability.onEnter.first.then((e) => completed = true);
          customScope.enter(null);
          expect(completed, isTrue);
        });
      });
    }, timeout: const Timeout(const Duration(milliseconds: 100)));
  });
}
