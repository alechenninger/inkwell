// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august;

import 'input.dart';
import 'src/persistence.dart';

export 'dart:async';

export 'package:quiver/time.dart' show Clock;

export 'input.dart';
export 'src/observable.dart';
export 'src/persistence.dart';
export 'src/scope.dart';
export 'src/story.dart';

// Experimenting with a Module type to capture module design pattern
abstract class Module<UiType> {
  UiType ui(Sink<Interaction> interactionSink);
  Interactor interactor();
}


