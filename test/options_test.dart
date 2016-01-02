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

  group("when made available and unavailable in same loop", () {
    Option opt;

    setUp(() {
      opt = new Option("option", run);

      opt.available(const Always());
      opt.available(const Never());
    });

    test("emits AddOption", () {
      var addition = run.once((e) => e is AddOptionEvent);

      expect(addition, completes);
    }, timeout: const Timeout(const Duration(seconds: 1)));

    test("emits RemoveOptionEvent", () {
      var removal = run.once((e) => e is RemoveOptionEvent);

      expect(removal, completes);
    },
        timeout: const Timeout(const Duration(seconds: 1)),
        skip: "Known bug"); // FIXME

    test("is not available after removal", () {
      expect(opt.isAvailable, isFalse);
    });
  });

  group("Added options", () {
    test("are available immediately", () {
      var opt = new Option("", run);
      opt.available(const Always());
      expect(opt.isAvailable, isTrue);
    });

    test("emit AddOptionEvents.", () async {
      run.once((e) => e is AddOptionEvent).then((AddOptionEvent e) {
        expect(e.option.text, equals("option 1"));
      });

      new Option("option 1", run).available(const Always());
    }, timeout: const Timeout(const Duration(seconds: 1)));

    group("scope entry", () {
      test("fires in same loop as AddOptionEvent", () async {
        var opt = new Option("", run);
        var order = [];
        opt.availability.onEnter.first.then((_) {
          order.add("availibility");
          scheduleMicrotask(() => order.add("microtask"));
        });
        var addOption = run.once((e) => e is AddOptionEvent).then((_) {
          order.add("AddOptionEvent");
        });
        opt.available(const Always());

        await addOption;

        expect(order, equals(["availability", "AddOptionEvent", "microtask"]));
      });

      test("fires listeners in next loop", () {
        var opt = new Option("", run);
        var completed = false;
        opt.availability.onEnter.first.then((_) {
          completed = true;
        });
        opt.available(const Always());

        expect(completed, isFalse);
      });
    });
  });

  group("Adding same option", () {
    test("does make multiple available.", () {
      new Option("option 1", run).available(const Always());
      new Option("option 1", run).available(const Always());
      expect(options.available.map((o) => o.text),
          equals(["option 1", "option 1"]));
    }, skip: "Not sure if should be avail in same event loop or next");

    test("does emit multiple AddOptionEvents.", () async {
      new Option("option 1", run).available(const Always());

      await run.once((e) => e is AddOptionEvent);

      new Option("option 1", run).available(const Always());

      await run.once((e) => e is AddOptionEvent);
    }, timeout: const Timeout(const Duration(seconds: 1)));
  });

  // TODO: rewrite using available scope
//  group("Exclusive options", () {
//    test("are no longer available when one in set is used.", () {
//      options.addExclusive(["one", "two", "three"]);
//      options.use("one");
//      expect(options.available, isEmpty);
//    });
//
//    test("do not linger after an exclusive option is used.", () {
//      options.addExclusive(["one", "two", "three"]);
//      options.use("one");
//
//      options.add("one");
//      options.add("two");
//
//      options.use("one");
//
//      expect(options.available, equals(["two"]));
//    });
//
//    test("are no longer available when one in multiple sets is used.", () {
//      options.addExclusive(["one", "two", "three"]);
//      options.addExclusive(["three", "four", "five"]);
//
//      options.use("three");
//
//      expect(options.available, isEmpty);
//    });
//
//    test("are still available if a used option is not in set.", () {
//      options.addExclusive(["1", "2", "3"]);
//      options.addExclusive(["4", "5"]);
//
//      options.use("1");
//
//      expect(options.available, equals(["4", "5"]));
//    });
//
//    test(
//        "emit RemoveOptionEvent when removed due to exclusive option in same "
//        "set being used.", () async {
//      options.addExclusive(["1", "2", "3"]);
//
//      options.use("1");
//
//      await run.once((e) => e is RemoveOptionEvent).then((e) {
//        expect(e.name, equals("2"));
//      });
//
//      await run.once((e) => e is RemoveOptionEvent).then((e) {
//        expect(e.name, equals("3"));
//      });
//
//      return run
//          .once((e) => e is RemoveOptionEvent)
//          .timeout(const Duration(milliseconds: 500), onTimeout: () {});
//    });
//
//    test("emit UseOptionEvent when used.", () async {
//      options.addExclusive(["1", "2", "3"]);
//
//      options.use("1");
//
//      await run.once((e) => e is UseOptionEvent).then((e) {
//        expect(e.name, equals("1"));
//      });
//
//      return run
//          .once((e) => e is UseOptionEvent)
//          .timeout(const Duration(milliseconds: 500), onTimeout: () {});
//    });
//  });

  group("Used options", () {
    test("are not available.", () {
      new Option("option 1", run)
        ..available(const Always())
        ..use();

      // TODO: This test doesn't actually test
      expect(options.available, isEmpty);
    });

    test("emit UseOptionEvent.", () async {
      new Option("option 1", run)
        ..available(const Always())
        ..use();

      await run.once((e) => e is UseOptionEvent).then((UseOptionEvent e) {
        expect(e.option.text, equals("option 1"));
      });
    });
  });
}
