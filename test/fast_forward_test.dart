import 'dart:async';

import 'package:test/test.dart';
import 'package:august/core.dart';
import 'package:august/testing/fake_async.dart' show FakeAsync;

void main() {
  var initialTime = new DateTime.fromMillisecondsSinceEpoch(0);

  group("fastForward", () {
    test("triggers futures within the fast forwarded time frame in order", () {
      new FakeAsync().run((async) {
        var occurred = [];

        fastForward((_) {
          new Future.delayed(
              const Duration(seconds: 1), () => occurred.add("first"));
          new Future.delayed(
              const Duration(seconds: 5), () => occurred.add("second"));
        }, async.getClock(initialTime), const Duration(seconds: 10));

        async.elapse(Duration.ZERO);

        expect(occurred, equals(["first", "second"]));
      });
    });

    test("provides accurate account of current play time during fast forward",
        () {
      new FakeAsync().run((async) {
        var times = {};

        fastForward((time) {
          times[0] = time();
          new Future.delayed(
              const Duration(seconds: 1), () => times[1] = time());
          new Future.delayed(
              const Duration(seconds: 5), () => times[2] = time());
        }, async.getClock(initialTime), const Duration(seconds: 10));

        async.elapse(Duration.ZERO);

        expect(
            times,
            equals({
              0: Duration.ZERO,
              1: const Duration(seconds: 1),
              2: const Duration(seconds: 5)
            }));
      });
    });

    test("switches to parent zone timer after fast forward offset", () {
      new FakeAsync().run((async) {
        var occurred = [];

        fastForward((_) {
          new Future.delayed(
              const Duration(seconds: 1), () => occurred.add("first"));
          new Future.delayed(
              const Duration(seconds: 5), () => occurred.add("second"));
        }, async.getClock(initialTime), const Duration(seconds: 2));

        async.elapse(const Duration(seconds: 2, milliseconds: 999));
        expect(occurred, equals(["first"]));
        async.elapse(const Duration(milliseconds: 1));
        expect(occurred, equals(["first", "second"]));
      });
    });

    test("fast forwards timers created as a result of other timers", () {
      new FakeAsync().run((async) {
        var occurred = false;

        fastForward((_) {
          new Future.delayed(const Duration(seconds: 1), () {
            new Future.delayed(const Duration(seconds: 2), () {
              new Future.delayed(const Duration(seconds: 3), () {
                occurred = true;
              });
            });
          });
        }, async.getClock(initialTime), const Duration(seconds: 6));

        async.elapse(Duration.ZERO);
        expect(occurred, true);
      });
    });

    test("allows scheduling future to add to sync broadcast stream", () {
      new FakeAsync().run((async) {
        var ctrl = new StreamController.broadcast(sync: true);

        fastForward((_) {
          ctrl.stream.where((_) => _ == 'foo').listen((_) {
            new Future(() => ctrl.add("got it!"));
          });

          ctrl.add("foo");
        }, async.getClock(initialTime), const Duration(seconds: 6));

        // If this does not fail, we are good
        async.elapse(const Duration(seconds: 1));
      });
    });
  });
}
