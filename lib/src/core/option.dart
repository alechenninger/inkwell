// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

abstract class Option {
  String get title;

  factory Option.singleUse(String title, Event event) {
    return new _SingleUseOption(title, event);
  }

  void trigger(Game game);
}

/// Options present [Event]s that are triggerable by an intelligent [Actor]
/// (either human or AI). Options are usually presented via a user interface
/// component and triggered by user input, like keyboard, touch, or mouse. To
/// "trigger" an option is to broadcast its associated [Event].
class _SingleUseOption implements Option {
  final String title;
  final Event _event;

  // TODO: Need to keep track of 'triggered' status?
  // In other words, is it possible that trigger can be called >1 time before
  // RemoveOption event is handled?

  _SingleUseOption(this.title, this._event) {
    checkNotNull(title);
    checkNotNull(_event);
  }

  void trigger(Game game) {
    game.broadcast(new RemoveOption(this));
    game.broadcast(_event);
  }

  @override
  String toString() => "_SingleUseOption(title: $title, _event: $_event)";
}