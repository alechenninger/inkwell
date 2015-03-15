// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

abstract class Event {
  final DateTime timeStamp = new DateTime.now();
}

class BeginEvent extends Event {
  @override
  String toString() => "$timeStamp > BeginEvent()";
}

class DialogEvent extends Event {
  final Actor speaker;
  final Actor target;
  final String what;

  DialogEvent(this.speaker, this.what, {this.target});

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

/// Changes the inventory content of an actor.
class InventoryEvent extends Event {

}

class AddActor extends Event {
  final Actor actor;

  AddActor(this.actor) {
    checkNotNull(actor, message: 'Actor cannot be null.');
  }

  @override
  String toString() => "$timeStamp > AddActor(actor: $actor)";
}