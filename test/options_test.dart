import 'package:august/august.dart';
import 'package:august/options.dart';
import 'package:test/test.dart';

void main() {
  var options = Options();

  group('An available Option', () {
    Option opt;

    setUp(() {
      opt = options.oneTime('');
    });

    test('is available', () {
      expect(opt.isAvailable, isTrue);
    });

    group('when used', () {
      test('is not immediately made unavailable', () {
        opt.use();
        expect(opt.isAvailable, isTrue);
      });

      test('is unavailable after use future completes', () async {
        await opt.use();
        expect(opt.isAvailable, isFalse);
      });

      test('is unavailable to use listeners', () async {
        var log = [];
        opt.onUse.listen((_) => log.add(opt.isAvailable));
        opt.use();
        await Future(() {});
        expect(log, equals([false]));
      });

      test('future completes before listeners fired', () async {
        var log = [];
        opt.onUse.listen((_) => log.add('listener'));
        await opt.use();
        expect(log, equals([]));
      });

      test('cannot be used again', () {
        opt.use().catchError((_) {});
        expect(opt.use(), throwsA(isA<OptionNotAvailableException>()));
      });

      test('fires use listeners', () {
        var listener = opt.onUse.first;
        opt.use();
        expect(listener, completes);
      });
    });
  });

  group('An unavailable Option', () {
    Option opt;
    SettableScope customScope;

    setUp(() {
      customScope = SettableScope.notEntered();
      opt = options.oneTime('', available: customScope);
    });

    group('when made available', () {
      test('is immediately available', () {
        customScope.enter();
        expect(opt.isAvailable, isTrue);
      });

      test('fires availability listeners in next microtask', () async {
        var order = [];

        opt.availability.onEnter.listen(
            (e) => order.add('listener isAvailable: ${opt.isAvailable}'));

        customScope.enter();
        await Future.microtask(
            () => order.add('mt isAvailable: ${opt.isAvailable}'));

        expect(order,
            equals(['listener isAvailable: true', 'mt isAvailable: true']));
      });
    });
  }, timeout: const Timeout(Duration(milliseconds: 500)));
}
