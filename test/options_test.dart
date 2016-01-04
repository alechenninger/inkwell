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
      test("enteres availability scope", () {
        opt.available(const Always());
        expect(opt.availability.onEnter.first, completes);
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

      test("emits availability in future after updating isAvailable", () async {
        opt.available(const Always());
        var order = [];
        new Future(() => order.add("future isAvailable: ${opt.isAvailable}"));
        await opt.availability.onEnter.first.then(
            (e) => order.add("availability isAvailable: ${opt.isAvailable}"));

        expect(
            order,
            equals([
              "future isAvailable: true",
              "availability isAvailable: true"
            ]));
      });

      group("via scope onEnter listener", () {
        SettableScope customScope;

        setUp(() {
          customScope = new SettableScope.notEntered();
          opt.available(customScope);
        });

        test("is not immediately available", () {
          customScope.enter(null);
          expect(opt.isAvailable, isFalse);
        });

        test("emits availability in future after updating isAvailable",
            () async {
          customScope.enter(null);
          var order = [];
          new Future(() => order.add("future isAvailable: ${opt.isAvailable}"));
          await opt.availability.onEnter.first.then(
              (e) => order.add("availability isAvailable: ${opt.isAvailable}"));

          expect(
              order,
              equals([
                "future isAvailable: true",
                "availability isAvailable: true"
              ]));
        });
      });
    }, timeout: const Timeout(const Duration(milliseconds: 100)));
  });
}
