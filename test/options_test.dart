import 'package:august/august.dart';
import 'package:august/options.dart';
import 'package:test/test.dart';

main() {
  group("An available Option", () {
    Option opt;

    setUp(() {
      opt = Option("");
    });

    test("is available", () {
      expect(opt.isAvailable, isTrue);
    });

    group('when used', () {
      test('is not immediately made unavailable', () {
        opt.use();
        expect(opt.isAvailable, isTrue);
      });

      test('is unavailable after use future completes', () {

      });

      test('is unavailable to use listeners', () {

      });

      test('cannot be used again', () {
        opt.use().catchError((_) {});
        expect(opt.use(), throws);
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
      opt = Option('', available: customScope);
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
