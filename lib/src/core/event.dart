// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

abstract class Event implements JsonEncodable {
  void set _timeStamp(Duration timeStamp);
  Duration get timeStamp;
}

abstract class EventSupport extends Event {
  final Map<String, dynamic> _state;

  EventSupport([this._state = const {}]);

  UnmodifiableMapView get state => new UnmodifiableMapView(_state);
}

class BeginEvent extends EventSupport {}

class DialogEvent extends EventSupport {
  Actor get speaker => state['speaker'];
  Actor get target => state['target'];
  String get what => state['what'];

  DialogEvent(speaker, what, {target})
      : super({'speaker': speaker, 'what': what, 'target': target});

  @override
  String toString() => "$timeStamp > "
      "DialogEvent(speaker: $speaker, target: $target, what: $what)";
}

class AddOption extends Event {
  final Option option;

  AddOption(this.option) {
    checkNotNull(option, message: "Option cannot be null.");
  }

  @override
  String toString() => "$timeStamp > AddOption(option: $option)";
}

class RemoveOption extends Event {
  final Option option;

  RemoveOption(this.option) {
    checkNotNull(option, message: "Option cannot be null.");
  }

  @override
  String toString() => "$timeStamp > RemoveOption(option: $option)";
}

class AddActor extends Event {
  final String actor;

  AddActor(this.actor) {
    checkNotNull(actor, message: 'Actor cannot be null.');
  }

  @override
  String toString() => "$timeStamp > AddActor(actor: $actor)";
}
