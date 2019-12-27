// Copyright (c) 2016, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:benchmark_harness/benchmark_harness.dart';
import 'dart:math';
import 'dart:async';

// fixed seed random for both runs
final Random random = Random(Random().nextInt(1000));
const int maxInt = 100;
const int eventsPerRun = 1000;
const int listeners = 2000;
const int filterIncrement = 50;

class ListenerBenchmark extends BenchmarkBase {
  ListenerBenchmark() : super('listener benchmark');

  var _ctrl = StreamController<Event>.broadcast(sync: true);
  var eventNumbers =
      List<int>.generate(eventsPerRun, (i) => random.nextInt(maxInt));
  int matches = 0;

  void run() {
    for (var i in eventNumbers) {
      _ctrl.add(Event(i));
    }
  }

  void setup() {
    for (var i = 0; i < maxInt; i += filterIncrement) {
      var filtered = _ctrl.stream
          .where((e) => e.number < i && e.number >= i - filterIncrement);

      for (var l = 0; l < listeners / (maxInt / filterIncrement); l++) {
        filtered
            .where((e) => e.number == random.nextInt(filterIncrement) + i)
            .listen((e) {
          matches++;
        });
      }
    }
  }

  void teardown() {
    _ctrl.close();
    _ctrl = null;
  }
}

class ControllerBenchmark extends BenchmarkBase {
  ControllerBenchmark() : super('controller benchmark');

  var _ctrl = StreamController<Event>.broadcast(sync: true);
  var eventNumbers =
      List<int>.generate(eventsPerRun, (i) => random.nextInt(maxInt));
  int matches = 0;

  void run() {
    for (var i in eventNumbers) {
      _ctrl.add(Event(i));
    }
  }

  void setup() {
    for (var i = 0; i < maxInt; i += filterIncrement) {
      var ctrl = StreamController.broadcast(sync: true);
      _ctrl.stream
          .where((e) => e.number < i && e.number >= i - filterIncrement)
          .listen((e) {
        ctrl.add(e);
      }, onDone: () {
        ctrl.close();
        ctrl = null;
      });

      for (var l = 0; l < listeners / (maxInt / filterIncrement); l++) {
        ctrl.stream
            .where((e) => e.number == random.nextInt(filterIncrement) + i)
            .listen((e) {
          matches++;
        });
      }
    }
  }

  void teardown() {
    _ctrl.close();
    _ctrl = null;
  }
}

class Event {
  final int number;

  Event(this.number);
}

void main() {
  ControllerBenchmark().report();
  ListenerBenchmark().report();
}
