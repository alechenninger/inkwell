import 'dart:async';
import 'package:meta/meta.dart';

abstract class UiEvent {
  String get event;
  Map<String, dynamic> get parameters;
}

extension UiEventStream on Stream<UiEvent> {
  Stream<UiEvent> ofType(String event) => where((e) => e.event == event);
}

abstract class Test {
  @protected String get test;
}

class TestIt extends Test {
  @protected
  final String test = '';
}

mixin UiObject {

}

void k() {
  TestIt().test;
}
