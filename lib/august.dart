// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

library august;

import 'dart:async';

import 'src/event_stream.dart';

export 'dart:async';

export 'narrator.dart';
export 'src/core.dart';
export 'src/observable.dart';
export 'src/persistence.dart';
export 'src/scope.dart';

Future delay({int seconds}) {
  return Future.delayed(Duration(seconds: seconds));
}
