import 'dart:math';

import 'package:august/august.dart';
import 'package:august/options.dart';
import 'package:test/test.dart';

void main() {
  group('merged observables', () {
    Observable<num> o1;
    Observable<num> o2;

    setUp(() {
      o1 = Observable.ofImmutable(1);
      o2 = Observable.ofImmutable(2);
    });

    test('current value is output of merge function', () {
      var merged = o1.merge(o2, (v1, v2) => v1 + v2);
      expect(merged.value, 3);
    });

    test('next value is value of merge function', () {
      var merged = o1.merge(o2, (v1, v2) => v1 + v2);
      var next = merged.onChange.first;
      o1.value = 3;
      expect(next, completion(equals(Change(5))));
    });

    test('listeners are not notified for changes before subscribing', () {
      var merged = o1.merge(o2, (num v1, num v2) => max(v1, v2));
      o1.value = 3;
      var next = merged.onChange.first;

      expect(next, doesNotComplete);
    });
  });
}
