import 'dart:math';

import 'package:august/august.dart';
import 'package:august/options.dart';
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
    });
  });
}
