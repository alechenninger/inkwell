// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

abstract class Event {
  final String id = _uuid.v4();
}

class BeginEvent extends Event {}

class DialogEvent extends Event {
  final String speaker;
  final String target;
  final String dialog;

  DialogEvent(this.speaker, this.dialog, {this.target});
  DialogEvent.fromJson(Map json)
      : speaker = json["speaker"],
        target = json["target"],
        dialog = json["dialog"];

  String toString() => "$id > "
      "DialogEvent(speaker: $speaker, target: $target, dialog: $dialog)";

  Map toJson() => {"speaker": speaker, "target": target, "dialog": dialog};
}

class AddOption extends Event {
  final Option option;

  AddOption(this.option);
  AddOption.fromJson(Map json, Script script)
      : option = new Option.fromJson(json["option"], script);

  String toString() => "$id > AddOption(option: $option)";

  Map toJson() => {"option": option};
}

class RemoveOption extends Event {
  final Option option;

  RemoveOption(this.option);
  RemoveOption.fromJson(Map json, Script script)
      : option = new Option.fromJson(json["option"], script);

  String toString() => "$id > RemoveOption(option: $option)";

  Map toJson() => {"option": option};
}

class AddActor extends Event {
  final String actor;

  AddActor(this.actor);
  AddActor.fromJson(Map json) : actor = json["actor"];

  String toString() => "$id > AddActor(actor: $actor)";

  Map toJson() => {"actor": actor};
}

Map<Type, EventDeserializer> _defaultEvents = {
  DialogEvent: (json, script) => new DialogEvent.fromJson(json),
  AddActor: (json, script) => new AddActor.fromJson(json),
  AddOption: (json, script) => new AddOption.fromJson(json, script),
  RemoveOption: (json, script) => new RemoveOption.fromJson(json, script)
};
