import 'package:quiver/testing/async.dart';
import 'package:test/test.dart';
import 'package:august/august.dart';

void main() {
  PausableZone zone;
  List<String> log;
  FakeAsync fakeAsync;

  setUp(() {
    log = [];
    fakeAsync = FakeAsync();
  });

  PausableZone pausableZone() {
    var start = DateTime.now();
    var clock = fakeAsync.getClock(start);
    return PausableZone(() {
      var now = clock.now();
      return now.difference(start);
    });
  }

  test('timers created while paused do not run', () {
    fakeAsync.run((async) {
      zone = pausableZone();
      zone.run((ctrl) {
        ctrl.pause();

        Timer(Duration(seconds: 2), () {
          log.add('test');
        });
      });

      async.elapse(Duration(seconds: 3));

      expect(log, isEmpty);
    });
  });

  test('periodic timers created while paused do not run', () {
    fakeAsync.run((async) {
      zone = pausableZone();
      zone.run((ctrl) {
        ctrl.pause();

        Timer.periodic(Duration(seconds: 2), (t) {
          log.add('test');
        });
      });

      async.elapse(Duration(seconds: 3));

      expect(log, isEmpty);
    });
  });

  test('timers created while paused run after unpausing', () {
    fakeAsync.run((async) {
      zone = pausableZone();
      zone.run((ctrl) {
        ctrl.pause();

        Timer(Duration(seconds: 2), () {
          log.add('test');
        });

        Zone.current.parent.createTimer(Duration(seconds: 1), () {
          ctrl.resume();
          // paused for 1 second
        });
      });

      async.elapse(Duration(seconds: 3));

      expect(log, equals(['test']));
    });
  });

  test('periodic timers created while paused run after unpausing', () {
    fakeAsync.run((async) {
      zone = pausableZone();
      zone.run((ctrl) {
        ctrl.pause();

        Timer.periodic(Duration(seconds: 2), (t) {
          log.add('test');
        });

        Zone.current.parent.createTimer(Duration(seconds: 1), () {
          ctrl.resume();
        });
      });

      async.elapse(Duration(seconds: 5));

      expect(log, equals(['test', 'test']));
    });
  });

  test('unpaused timers do run', () {
    fakeAsync.run((async) {
      zone = pausableZone();
      zone.run((ctrl) {
        Timer(Duration(seconds: 2), () {
          log.add('test');
        });
      });

      async.elapse(Duration(seconds: 2));

      expect(log, equals(['test']));
    });
  });

  test('paused timers do not run', () {
    fakeAsync.run((async) {
      zone = pausableZone();
      zone.run((ctrl) {
        Timer(Duration(seconds: 2), () {
          log.add('test');
        });
        Timer(Duration(seconds: 1), () {
          ctrl.pause();
        });
      });

      async.elapse(Duration(seconds: 3));

      expect(log, isEmpty);
    });
  });

  test('paused periodic timers do not run', () {
    fakeAsync.run((async) {
      zone = pausableZone();
      zone.run((ctrl) {
        Timer.periodic(Duration(seconds: 2), (t) {
          log.add('test');
        });
        Timer(Duration(seconds: 1), () {
          ctrl.pause();
        });
      });

      async.elapse(Duration(seconds: 3));

      expect(log, isEmpty);
    });
  });

  test('unpaused timers run after remaining time', () {

  });

  test('unpaused timers do not run before remaining time', () {
    fakeAsync.run((async) {
      zone = pausableZone();
      zone.run((ctrl) {
        Timer(Duration(seconds: 2), () {
          log.add('test');
        });
        Timer(Duration(seconds: 1), () {
          ctrl.pause();
          // timer has 1 second remaining
        });

        Zone.current.parent.createTimer(Duration(seconds: 2), () {
          ctrl.resume();
        });
      });

      async.elapse(Duration(seconds: 2, milliseconds: 999));

      expect(log, isEmpty);
    });
  });

  test('unpaused periodic timers run after remaining time', () {
    fakeAsync.run((async) {
      zone = pausableZone();
      zone.run((ctrl) {
        Timer.periodic(Duration(seconds: 2), (t) {
          log.add('test');
        });
        Timer(Duration(seconds: 1), () {
          ctrl.pause();
          // timer has 1 second remaining
        });

        Zone.current.parent.createTimer(Duration(seconds: 2), () {
          ctrl.resume();
          // paused for 1 second
        });
      });

      async.elapse(Duration(seconds: 3));

      expect(log, equals(['test']));
    });
  });

  test('unpaused periodic timers run periodically, offset by pause time', () {

  });

  test('unpaused timers retain order they were scheduled', () {

  });

  test('unpaused periodic timers retain order they were scheduled', () {

  });

  test(
      'upnaused periodic timers retain order when colliding with non periodic timers',
      () {

  });

  test('completed timers do not run after resuming', () {

  });

  // TODO: test cancellations
}
