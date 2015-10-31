import 'package:test/test.dart';
import 'package:august/core.dart';
import 'package:august/modules.dart';
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

  group("Added options", () {
    test("are available.", () {
      options.add("option 1");
      options.add("option 2");
      expect(options.available, equals(["option 1", "option 2"]));
    });

    test("emit AddOptionEvents.", () async {
      run.once((e) => e is AddOptionEvent).then((AddOptionEvent e) {
        expect(e.option.text, equals("option 1"));
      });

      options.add("option 1");
    }, timeout: const Timeout(const Duration(seconds: 1)));
  });

  group("Adding same option", () {
    test("does not make multiple available.", () {
      options.add("option 1");
      options.add("option 1");
      expect(options.available, equals(["option 1"]));
    });

    test("does not emit multiple AddOptionEvents.", () async {
      options.add("option 1");

      await run.once((e) => e is AddOptionEvent);

      options.add("option 1");

      return run.once((e) => e is AddOptionEvent).then((e) {
        fail("Got second AddOptionEvent: $e");
      }).timeout(const Duration(milliseconds: 100), onTimeout: () {});
    });

    test("is determined by name (which defaults to text).", () async {
      options.add("option 1");

      await run.once((e) => e is AddOptionEvent);

      options.add("alternate option 1", named: "option 1");

      await run.once((e) => e is AddOptionEvent).then((e) {
        fail("Got second AddOptionEvent: $e");
      }).timeout(const Duration(milliseconds: 100), onTimeout: () {});

      expect(options.available, equals(["option 1"]));
    });
  });

  group("Exclusive options", () {
    test("are no longer available when one in set is used.", () {
      options.addExclusive(["one", "two", "three"]);
      options.use("one");
      expect(options.available, isEmpty);
    });

    test("do not linger after an exclusive option is used.", () {
      options.addExclusive(["one", "two", "three"]);
      options.use("one");

      options.add("one");
      options.add("two");

      options.use("one");

      expect(options.available, equals(["two"]));
    });

    test("are no longer available when one in multiple sets is used.", () {
      options.addExclusive(["one", "two", "three"]);
      options.addExclusive(["three", "four", "five"]);

      options.use("three");

      expect(options.available, isEmpty);
    });

    test("are still available if a used option is not in set.", () {
      options.addExclusive(["1", "2", "3"]);
      options.addExclusive(["4", "5"]);

      options.use("1");

      expect(options.available, equals(["4", "5"]));
    });

    test(
        "emit RemoveOptionEvent when removed due to exclusive option in same "
        "set being used.", () async {
      options.addExclusive(["1", "2", "3"]);

      options.use("1");

      await run.once((e) => e is RemoveOptionEvent).then((e) {
        expect(e.name, equals("2"));
      });

      await run.once((e) => e is RemoveOptionEvent).then((e) {
        expect(e.name, equals("3"));
      });

      return run
          .once((e) => e is RemoveOptionEvent)
          .timeout(const Duration(milliseconds: 500), onTimeout: () {});
    });

    test("emit UseOptionEvent when used.", () async {
      options.addExclusive(["1", "2", "3"]);

      options.use("1");

      await run.once((e) => e is UseOptionEvent).then((e) {
        expect(e.name, equals("1"));
      });

      return run
          .once((e) => e is UseOptionEvent)
          .timeout(const Duration(milliseconds: 500), onTimeout: () {});
    });
  });

  group("Used options", () {
    test("are no longer available.", () {
      options.add("option 1");
      options.use("option 1");
      expect(options.available, isEmpty);
    });

    test("emit UseOptionEvent.", () async {
      options.add("option 1");
      options.use("option 1");

      await run.once((e) => e is UseOptionEvent).then((e) {
        expect(e.name, equals("option 1"));
      });
    });
  });
}
