
import 'package:inkwell/inkwell.dart';
import 'package:test/test.dart';

void main() {
  group('CountScope max 1', () {
    CountScope scope;

    setUp(() {
      scope = CountScope(1);
    });

    test('is immediately entered', () {
      expect(scope.isEntered, isTrue);
    });

    group('when incremented', () {
      test('is immediately exited', () {
        scope.increment();
        expect(scope.isEntered, isFalse);
      });

      test('emits exit event', () {
        var exit = scope.onExit.first;
        scope.increment();
        expect(exit, completes);
      });
    });

    group('with remaining', () {
      test('and remaining uses > 1, then is entered even if original scope is maxxed', () {
        scope.increment();
        var withRemaining = scope.withRemaining(1);
        expect(withRemaining.isEntered, isTrue);
      });

      test('after remaining increments, is immediately exited', () {
        var withRemaining = scope.withRemaining(1);
        withRemaining.increment();
        expect(withRemaining.isEntered, isFalse);
      });

      test('with some but not all remaining increments, is still entered', () {
        var withRemaining = scope.withRemaining(2);
        withRemaining.increment();
        expect(withRemaining.isEntered, isTrue);
      });

      test('increments original and with remaining scopes', () {
        var withRemaining = scope.withRemaining(1);
        withRemaining.increment();
        expect(withRemaining.count, equals(1));
        expect(scope.count, equals(1));
      });
    });
  }, timeout: Timeout(Duration(seconds: 1)));
}
