// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august;

import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:quiver/time.dart';

export 'dart:async';
export 'package:quiver/time.dart' show Clock;

export 'src/story.dart';

// TODO: This library organization is a mess
part 'input.dart';
part 'src/events.dart';
part 'src/persistence.dart';
part 'src/scope.dart';
part 'src/observable.dart';

// Experimenting with a Module type to capture module design pattern
abstract class Module<UiType> {
  String get name;
  UiType ui(InteractionManager mgr);
  Interactor interactor();
}
