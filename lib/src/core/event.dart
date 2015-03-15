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

/// Changes the global options available to a current player.
class OptionsEvent extends Event {

}

/// Changes the inventory content of an actor.
class InventoryEvent extends Event {

}