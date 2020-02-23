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
      var merged = o1.merge(o2, sum);
      expect(merged.value, 3);
    });

    test('next value is value of merge function', () {
      var merged = o1.merge(o2, sum);
      var next = merged.onChange.first;
      o1.value = 3;
      expect(next, completion(equals(Change(5))));
    });

    test('listeners are not notified for changes before subscribing', () {
      var merged = o1.merge(o2, max);
      o1.value = 3;
      var next = merged.onChange.first;

      expect(next, doesNotComplete);
    });

    test('listeners of merged value are notified in next microtask', () async {
      var log = <String>[];
      var merged = o1.merge(o2, sum);
      merged.onChange.listen((c) => log.add('listener: ${c.newValue}'));
      o1.value = 3;
      await Future.microtask(() => log.add('mt'));
      expect(log, equals(['listener: 5', 'mt']));
    });

    test(
        "emits changes when merged value returns back to previous with observable's first change",
        () async {
      var merged = o1.merge(o2, sum);
      var log = [];
      merged.onChange.listen((e) => log.add(e.newValue));
      o1.value = 3;
      // First change for o2, will return merge value back to first (3)
      o2.value = 0;
      await Future.microtask(() {});
      expect(log, equals([5, 3]));
    });

    test(
        'setting original observable to same value does not emit from merged observable',
        () async {
      var merged = o1.merge(o2, sum);
      var log = [];
      merged.onChange.listen((e) => log.add(e.newValue));
      o1.value = 1;
      await Future.microtask(() {});
      expect(log, equals([]));
    });

    test(
        'change to original that results in original merged value does not emit from merged observable',
        () async {
      // Note use of max
      var merged = o1.merge(o2, max);
      var log = [];
      merged.onChange.listen((e) => log.add(e.newValue));
      o1.value = 0;
      await Future.microtask(() {});
      expect(log, equals([]));
    });

    test(
        'changes to originals that result in new duplicate merged values do not emit from merged observable',
        () async {
      // Note use of max
      var merged = o1.merge(o2, max);
      var log = [];
      merged.onChange.listen((e) => log.add(e.newValue));
      o1.value = 3;
      o2.value = 3;
      await Future.microtask(() {});
      expect(log, equals([3]));
    });
  });

  group('mapped observable', () {});
}

num sum(num x, num y) => x + y;
