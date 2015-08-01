// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.example;

import 'package:august/core.dart';

main() {
  new Run(jackAndJillV1).start();
}

class Jack {}

class Jill {}

var jackAndJillV1 = new Script("Jack and Jill", "1.0.0",
    (Once once, Options options) {
  Jack jack = new Jack();
  Jill jill = new Jill();

  options.add("Talk to Jill");

  once("Talk to Jill").then((e) {

  });
});
