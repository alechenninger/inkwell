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
      fakeAsync.run((async) {
        zone.run((ctrl) {
          Timer(2.seconds, () {
            log.add('test');
          });
        });

        async.elapse(2.seconds);

        expect(log, equals(['test']));
      });
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

      test('runs when unpaused after 1 second', () {
        fakeAsync.run((async) {
          async.elapse(1.seconds);

          expect(log, equals(['test']));
        });
      });

      test('unpaused timers do not run before remaining time', () {
        fakeAsync.run((async) {
          async.elapse(999.millis);

          expect(log, isEmpty);
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
            log.add(ctrl.offset);
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

    test('unpaused periodic timers do not run before remaining time', () {
      fakeAsync.run((async) {
        zone.run((ctrl) {
          Timer.periodic(2.seconds, (t) {
            log.add('test');
          });
          Timer(1.seconds, () {
            ctrl.pause();
            // timer has 1 second remaining
          });
        });

        Timer(2.seconds, () {
          zone.resume();
          // paused for 1 second
        });

        async.elapse(2.seconds + 999.millis);

        expect(log, isEmpty);
      });
    });

    test('unpaused periodic timers run after remaining time', () {
      fakeAsync.run((async) {
        zone.run((ctrl) {
          Timer.periodic(2.seconds, (t) {
            log.add('test');
          });
          Timer(1.seconds, () {
            ctrl.pause();
            // timer has 1 second remaining
          });
        });

        Timer(2.seconds, () {
          zone.resume();
          // paused for 1 second
        });

        async.elapse(3.seconds);

        expect(log, equals(['test']));
      });
    });

    test('unpaused periodic timers run periodically, offset by pause time', () {
      fakeAsync.run((async) {
        zone.run((ctrl) {
          Timer.periodic(2.seconds, (t) {
            log.add(ctrl.offset);
          });
          Timer(1.seconds, () {
            ctrl.pause();
            // timer has 1 second remaining
          });
        });

        Timer(2.seconds, () {
          zone.resume();
          // paused for 1 second
        });

        async.elapse(5.seconds);

        expect(log, equals([3.seconds, 5.seconds]));
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
      Timer.periodic(5.seconds, (t) => log.add('p${ctrl.offset.inSeconds}'));
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
      'unpaused periodic timers scheduled after timers run after colliding timers',
      () {
    zone.run((ctrl) {
      Timer(10.seconds, () => log.add('t'));
      Timer.periodic(5.seconds, (t) => log.add('p${ctrl.offset.inSeconds}'));
      Timer(4.seconds, () => ctrl.pause());
    });

    fakeAsync.run((a) {
      Timer(5.seconds, () => zone.resume());
      a.elapse(11.seconds);
    });

    expect(log, equals(['p6', 't', 'p11']));
  });

  test(
      'unpaused periodic timers scheduled before shorter timers run after',
      () {
    zone.run((ctrl) {
      Timer.periodic(10.seconds, (t) => log.add('p${ctrl.offset.inSeconds}'));
      Timer(5.seconds, () => log.add('t'));
      Timer(4.seconds, () => ctrl.pause());
    });

    fakeAsync.run((a) {
      Timer(5.seconds, () => zone.resume());
      a.elapse(11.seconds);
    });

    expect(log, equals(['t', 'p11']));
  });

  test('complex order is retained', () {
    zone.run((ctrl) {
      Timer.periodic(5.seconds, (t) => log.add('p1_${ctrl.offset.inSeconds}'));
      Timer(10.seconds, () => log.add('t1'));
      Timer(20.seconds, () => log.add('t2'));
      Timer.periodic(10.seconds, (t) => log.add('p2_${ctrl.offset.inSeconds}'));
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

  test('completed timers do not run after resuming', () {});

  // TODO: test cancellations
}

extension Durations on int {
  Duration get seconds => Duration(seconds: this);
  Duration get millis => Duration(milliseconds: this);
}
