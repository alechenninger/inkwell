import 'package:quiver/testing/async.dart';
import 'package:test/test.dart';
import 'package:august/august.dart';

void main() {
  PausableZone zone;
  List<dynamic> log;
  FakeAsync fakeAsync;

  setUp(() {
    log = [];
    fakeAsync = FakeAsync();
    zone = fakeAsync.run((async) {
      var start = DateTime.now();
      var fakeClock = fakeAsync.getClock(start);
      return PausableZone(() => fakeClock.now().difference(start));
    }) as PausableZone;
  });

  group('non-periodic timers', () {
    test('created while paused do not run', () {
      fakeAsync.run((async) {
        zone.run((ctrl) {
          ctrl.pause();

          Timer(2.seconds, () {
            log.add('test');
          });
        });

        async.elapse(3.seconds);

        expect(log, isEmpty);
      });
    });

    test('created while paused run after unpausing', () {
      fakeAsync.run((async) {
        zone.run((ctrl) {
          ctrl.pause();

          Timer(2.seconds, () {
            log.add('test');
          });
        });

        Timer(1.seconds, () {
          zone.resume();
          // paused for 1 second
        });

        async.elapse(3.seconds);

        expect(log, equals(['test']));
      });
    });

    test('run when unpaused', () {
      zone.run((ctrl) {
        Timer(2.seconds, () => log.add('test'));
      });

      fakeAsync.run((async) => async.elapse(2.seconds));

      expect(log, equals(['test']));
    });

    test('do not run when paused', () {
      fakeAsync.run((async) {
        zone.run((ctrl) {
          Timer(2.seconds, () {
            log.add('test');
          });
          Timer(1.seconds, () {
            ctrl.pause();
          });
        });

        async.elapse(3.seconds);

        expect(log, isEmpty);
      });
    });

    group('unpaused with 1 second remaining', () {
      setUp(() {
        // t0 - start 2 second timer under test
        // t1 - pause (1 second remaining)
        // t2 - unpause (1 second remaining)

        zone.run((ctrl) {
          Timer(2.seconds, () {
            log.add('test');
          });
          Timer(1.seconds, () {
            ctrl.pause();
            // timer has 1 second remaining
          });
        });

        fakeAsync.run((async) {
          // Elapse both timers; now paused
          async.elapse(1.seconds);

          // 1 second later, unpause.
          Timer(1.seconds, () {
            zone.resume();
            // paused for 1 second
          });

          // Move to 1 second later; now unpaused
          async.elapse(1.seconds);
        });
      });

      test('runs when unpaused for 1 second', () {
        fakeAsync.run((async) {
          async.elapse(1.seconds);

          expect(log, equals(['test']));
        });
      });

      test('do not run before remaining time', () {
        fakeAsync.run((async) {
          async.elapse(999.millis);

          expect(log, isEmpty);
        });
      });

      group('paused again', () {
        setUp(() {
          fakeAsync.run((a) {
            Timer(.5.seconds, () => zone.pause());
            a.elapse(.5.seconds);
          });
        });

        test('do not run before resumed', () {
          fakeAsync.run((a) => a.elapse(60.seconds));
          expect(log, isEmpty);
        });

        group('resumed again', () {
          setUp(() {
            fakeAsync.run((a) {
              Timer(1.seconds, () => zone.resume());
              a.elapse(1.seconds);
            });
          });

          test('do not run before remaining time', () {
            fakeAsync.run((a) {
              a.elapse(.4.seconds);
            });

            expect(log, isEmpty);
          });

          test('run after remaining time', () {
            fakeAsync.run((a) {
              a.elapse(.5.seconds);
            });

            expect(log, equals(['test']));
          });
        });
      });
    });
  });

  group('periodic timers', () {
    test('created while paused do not run', () {
      fakeAsync.run((async) {
        zone.run((ctrl) {
          ctrl.pause();

          Timer.periodic(2.seconds, (t) {
            log.add('test');
          });
        });

        async.elapse(3.seconds);

        expect(log, isEmpty);
      });
    });

    test('created while paused run after unpausing', () {
      fakeAsync.run((async) {
        zone.run((ctrl) {
          ctrl.pause();

          Timer.periodic(2.seconds, (t) {
            log.add(ctrl.parentOffset);
          });
        });

        Timer(1.seconds, () {
          zone.resume();
          // paused for 1 second
        });

        async.elapse(5.seconds);

        expect(log, equals([3.seconds, 5.seconds]));
      });
    });

    test('do not run when paused', () {
      fakeAsync.run((async) {
        zone.run((ctrl) {
          Timer.periodic(2.seconds, (t) {
            log.add('test');
          });
          Timer(1.seconds, () {
            ctrl.pause();
          });
        });

        async.elapse(3.seconds);

        expect(log, isEmpty);
      });
    });

    group('paused before first period and unpaused', () {
      setUp(() {
        zone.run((ctrl) {
          Timer.periodic(
              4.seconds, (t) => log.add('p${ctrl.parentOffset.inSeconds}'));
          Timer(1.seconds, () => ctrl.pause());
        });

        fakeAsync.run((async) {
          Timer(2.seconds, () => zone.resume());
          async.elapse(2.seconds);
        });
      });

      test('do not run before remaining time', () {
        fakeAsync.run((async) => async.elapse(2.999.seconds));
        expect(log, isEmpty);
      });

      test('run after remaining time', () {
        fakeAsync.run((async) => async.elapse(3.seconds));
        expect(log, equals(['p5']));
      });

      test('run periodically, offset by pause time', () {
        fakeAsync.run((async) => async.elapse(9.seconds));
        expect(log, equals(['p5', 'p9']));
      });

      group('paused again', () {
        setUp(() {
          fakeAsync.run((a) {
            Timer(1.seconds, () => zone.pause());
            a.elapse(1.seconds);
          });
        });

        test('do not run before resumed', () {
          fakeAsync.run((a) => a.elapse(60.seconds));
          expect(log, isEmpty);
        });

        group('resumed again', () {
          setUp(() {
            fakeAsync.run((a) {
              Timer(2.seconds, () => zone.resume());
              a.elapse(2.seconds);
            });
          });

          test('run perodically, offset by paused time', () {
            fakeAsync.run((a) => a.elapse(6.seconds));
            expect(log, equals(['p7', 'p11']));
          });
        });
      });
    });
  });

  test('unpaused timers retain order they were scheduled', () {
    zone.run((ctrl) {
      Timer(10.seconds, () => log.add('first'));
      Timer(10.seconds, () => log.add('second'));
      Timer(4.seconds, () => ctrl.pause());
    });

    fakeAsync.run((a) {
      Timer(5.seconds, () => zone.resume());
      a.elapse(11.seconds);
    });

    expect(log, equals(['first', 'second']));
  });

  test('unpaused periodic timers retain order they were scheduled', () {
    zone.run((ctrl) {
      Timer.periodic(10.seconds, (t) => log.add('first'));
      Timer.periodic(10.seconds, (t) => log.add('second'));
      Timer(4.seconds, () => ctrl.pause());
    });

    fakeAsync.run((a) {
      Timer(5.seconds, () => zone.resume());
      a.elapse(11.seconds);
    });

    expect(log, equals(['first', 'second']));
  });

  test(
      'unpaused periodic timers scheduled before timers run before colliding timers',
      () {
    zone.run((ctrl) {
      Timer.periodic(
          5.seconds, (t) => log.add('p${ctrl.parentOffset.inSeconds}'));
      Timer(10.seconds, () => log.add('t'));
      Timer(4.seconds, () => ctrl.pause());
    });

    fakeAsync.run((a) {
      Timer(5.seconds, () => zone.resume());
      a.elapse(11.seconds);
    });

    expect(log, equals(['p6', 'p11', 't']));
  });

  test(
      'unpaused periodic timers scheduled before timers run before colliding timers multiple pauses',
      () {
    zone.run((ctrl) {
      Timer.periodic(
          5.seconds, (t) => log.add('p${ctrl.parentOffset.inSeconds}'));
      Timer(10.seconds, () => log.add('t'));
    });

    fakeAsync.run((a) {
      Timer(2.seconds, () => zone.pause());
      Timer(3.seconds, () => zone.resume());
      Timer(7.seconds, () => zone.pause());
      Timer(8.seconds, () => zone.resume());
      a.elapse(12.seconds);
    });

    expect(log, equals(['p6', 'p12', 't']));
  });

  test(
      'unpaused periodic timers scheduled before timers run before colliding timers multiple pauses within a period',
      () {
    zone.run((ctrl) {
      Timer.periodic(
          5.seconds, (t) => log.add('p${ctrl.parentOffset.inSeconds}'));
      Timer(10.seconds, () => log.add('t'));
    });

    fakeAsync.run((a) {
      Timer(2.seconds, () => zone.pause());
      Timer(3.seconds, () => zone.resume());
      Timer(4.seconds, () => zone.pause());
      Timer(5.seconds, () => zone.resume());
      a.elapse(12.seconds);
    });

    expect(log, equals(['p7', 'p12', 't']));
  });

  test(
      'unpaused periodic timers scheduled after timers run after colliding timers',
      () {
    zone.run((ctrl) {
      Timer(10.seconds, () => log.add('t'));
      Timer.periodic(
          5.seconds, (t) => log.add('p${ctrl.parentOffset.inSeconds}'));
      Timer(4.seconds, () => ctrl.pause());
    });

    fakeAsync.run((a) {
      Timer(5.seconds, () => zone.resume());
      a.elapse(11.seconds);
    });

    expect(log, equals(['p6', 't', 'p11']));
  });

  test('unpaused periodic timers scheduled before shorter timers run after',
      () {
    zone.run((ctrl) {
      Timer.periodic(
          10.seconds, (t) => log.add('p${ctrl.parentOffset.inSeconds}'));
      Timer(5.seconds, () => log.add('t'));
      Timer(4.seconds, () => ctrl.pause());
    });

    fakeAsync.run((a) {
      Timer(5.seconds, () => zone.resume());
      a.elapse(11.seconds);
    });

    expect(log, equals(['t', 'p11']));
  });

  test('complex order is retained 2', () {
    zone.run((ctrl) {
      Timer.periodic(
          15.seconds, (t) => log.add('p2_${ctrl.parentOffset.inSeconds}'));
      Timer(10.seconds, () => log.add('t1'));
      Timer.periodic(
          5.seconds, (t) => log.add('p1_${ctrl.parentOffset.inSeconds}'));
      Timer(4.seconds, () => ctrl.pause());
    });

    fakeAsync.run((a) {
      Timer(5.seconds, () => zone.resume());
      a.elapse(16.seconds);
    });

    expect(log, equals(['p1_6', 't1', 'p1_11', 'p2_16', 'p1_16']));
  });

  test('complex order is retained 3', () {
    zone.run((ctrl) {
      Timer.periodic(
          5.seconds, (t) => log.add('p1_${ctrl.parentOffset.inSeconds}'));
      Timer.periodic(
          15.seconds, (t) => log.add('p2_${ctrl.parentOffset.inSeconds}'));
      Timer(10.seconds, () => log.add('t1'));
      Timer(4.seconds, () => ctrl.pause());
    });

    fakeAsync.run((a) {
      Timer(5.seconds, () => zone.resume());
      a.elapse(16.seconds);
    });

    expect(log, equals(['p1_6', 'p1_11', 't1', 'p1_16', 'p2_16']));
  });

  test('complex order is retained', () {
    zone.run((ctrl) {
      Timer.periodic(
          5.seconds, (t) => log.add('p1_${ctrl.parentOffset.inSeconds}'));
      Timer(10.seconds, () => log.add('t1'));
      Timer(20.seconds, () => log.add('t2'));
      Timer.periodic(
          10.seconds, (t) => log.add('p2_${ctrl.parentOffset.inSeconds}'));
      Timer(4.seconds, () => ctrl.pause());
    });

    fakeAsync.run((a) {
      Timer(5.seconds, () => zone.resume());
      a.elapse(21.seconds);
    });

    expect(
        log,
        equals(
            ['p1_6', 'p1_11', 't1', 'p2_11', 'p1_16', 'p1_21', 't2', 'p2_21']));
  });

  test('complex order is retained after multiple pauses', () {
    zone.run((ctrl) {
      Timer.periodic(
          5.seconds, (t) => log.add('p1_${ctrl.parentOffset.inSeconds}'));
      Timer(10.seconds, () => log.add('t1'));
      Timer(20.seconds, () => log.add('t2'));
      Timer.periodic(
          10.seconds, (t) => log.add('p2_${ctrl.parentOffset.inSeconds}'));
    });

    fakeAsync.run((a) {
      // Pause for 1 second, at 4 seconds
      Timer(4.seconds, () => zone.pause()); // 1 second remaining
      Timer(5.seconds, () => zone.resume());
      // t6 runs, next run t11 (5 seconds)

      // t8, pause for 2 seconds
      Timer(8.seconds, () => zone.pause()); // 3 seconds remaining
      Timer(10.seconds, () => zone.resume());

      a.elapse(23.seconds);
    });

    expect(
        log,
        equals(
            ['p1_6', 'p1_13', 't1', 'p2_13', 'p1_18', 'p1_23', 't2', 'p2_23']));
  });

  test('completed timers do not run after resuming', () {
    zone.run((ctrl) {
      Timer(1.seconds, () => log.add('t1'));
      Timer(1.seconds, () => ctrl.pause());
    });

    fakeAsync.run((a) {
      Timer(1.seconds, () => zone.resume());
      a.elapse(5.seconds);
    });

    expect(log, equals(['t1']));
  });

  // TODO: test cancellations
  // TODO: test timers which create other timers
}

extension IntDurations on int {
  Duration get seconds => Duration(seconds: this);
  Duration get millis => Duration(milliseconds: this);
}

extension DblDurations on double {
  Duration get seconds => (this * 1000).truncate().millis;
}
