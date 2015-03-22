// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

abstract class Event {
  DateTime _timeStamp = null;
  DateTime get timeStamp => _timeStamp;
  bool get hasOccurred => timeStamp == null;

  String toString() => "$timeStamp > ${this.runtimeType}()";
}

abstract class TargetedEvent extends Event {
  Actor get target;
}

class BeginEvent extends Event {}

class DialogEvent extends TargetedEvent {
  final Actor speaker;
  final Actor target;
  final String what;

  DialogEvent(this.speaker, this.what, {this.target});

  @override
  String toString() => "$timeStamp > "
      "DialogEvent(speaker: $speaker, target: $target, what: $what)";
}

class ModalDialogEvent extends TargetedEvent {
  final Actor speaker;
  final Actor target;
  final String what;
  final Iterable<Reply> replies;

  ModalDialogEvent(this.speaker, this.what, this.target, this.replies);

  @override
  String toString() => "$timeStamp > "
      "ModalDialogEvent(speaker: $speaker, target: $target, what: $what, "
      "replies: $replies";
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
class InventoryEvent extends TargetedEvent {

}

class AddActor extends Event {
  final Actor actor;

  AddActor(this.actor) {
    checkNotNull(actor, message: 'Actor cannot be null.');
  }

  @override
  String toString() => "$timeStamp > AddActor(actor: $actor)";
}