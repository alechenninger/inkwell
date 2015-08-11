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

        async.elapse(const Duration(seconds: 1));

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

        async.elapse(const Duration(seconds: 1));

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
  });
}
