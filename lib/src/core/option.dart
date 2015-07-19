// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

/// Global "option" that represents a decision point for a player.
class Option {
  final String title;
  final Event _event;
  int _available;

  Option(this.title, this._event, {int available: 1}) {
    _available = available;
  }

  Option.fromJson(Map json, Script script)
      : title = json["title"],
        _event = script.getEvent(json["event"]["type"], json["event"]["data"]) {
    _available = json["available"];
  }

  int get available => _available;

  void trigger(void broadcast(Event e)) {
    if (_available < 1) {
      throw new StateError("Cannot use an option if it is not available.");
    }

    _available = _available - 1;
    if (_available == 0) {
      broadcast(new RemoveOption(this));
    }

    broadcast(_event);
  }

  Map toJson() => {
    "title": title,
    "available": available,
    "event": {"type": _event.runtimeType, "data": _event}
  };
}

/// Single use "option" as a result of a specific event.
class Reply {
  final String title;

  /// The event that should be triggered as a result of replying with this
  /// [Reply].
  final Event event;

  /// See [event]
  Reply(this.title, this.event);

  Map toJson() => {"title": title, "event": event};
}
