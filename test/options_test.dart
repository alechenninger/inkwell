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
      test("enters availability scope", () {
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

      test("emits availability same future as updating isAvailable", () async {
        opt.available(const Always());
        var order = [];
        var future = new Future(
            () => order.add("future isAvailable: ${opt.isAvailable}"));
        opt.availability.onEnter.first.then(
            (e) => order.add("availability isAvailable: ${opt.isAvailable}"));

        await future;

        expect(
            order,
            equals([
              "availability isAvailable: true",
              "future isAvailable: true"
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

        test("emits availability in same future as updating isAvailable",
            () async {
          customScope.enter(null);
          var order = [];
          var future = new Future(
              () => order.add("future isAvailable: ${opt.isAvailable}"));
          opt.availability.onEnter.first.then(
              (e) => order.add("availability isAvailable: ${opt.isAvailable}"));
          await future;

          expect(
              order,
              equals([
                "availability isAvailable: true",
                "future isAvailable: true"
              ]));
        });
      });
    });

    group("when used", () {
      setUp(() {
        opt.available(const Always());
        return opt.availability.onEnter.first;
      });

      test("is not immediately made unavailable", () {
        opt.use();
        expect(opt.isAvailable, isTrue);
      });

      test("makes an option unavailable to new futures", () {
        opt.use();
        expect(new Future(() => opt.isAvailable), completion(isFalse));
      });

      test("completes with error if option is scheduled to be unavailable", () {
        opt.available(const Never());
        expect(opt.use(), throws);
      });

      test("completes with error if option is already unavailable", () async {
        opt.available(const Never());
        await opt.availability.onExit.first;
        expect(opt.use(), throws);
      });

      test("emits UseOptionEvent", () {
        opt.use();
        expect(run.once((e) => e is UseOptionEvent), completes);
      });

      test("does not emit UseOptionEvent if not available to be used", () {
        opt.available(const Never());
        opt.use().catchError((e) {});
        expect(
            run
                .once((e) => e is UseOptionEvent)
                .timeout(const Duration(milliseconds: 250)),
            throws);
      });
    });
  }, timeout: const Timeout(const Duration(milliseconds: 500)));
}
