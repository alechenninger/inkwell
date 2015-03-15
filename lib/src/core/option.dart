// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

/// Options present [Event]s that are triggerable by an intelligent [Actor]
/// (either human or AI). Options are usually presented via a user interface
/// component and triggered by user input, like keyboard, touch, or mouse. To
/// "trigger" an option is to broadcast its associated [Event].
class Option {
  final String title;
  final Event _event;

  // TODO: Need to keep track of 'triggered' status?
  // In other words, is it possible that trigger can be called >1 time before
  // RemoveOption event is handled?

  Option.singleUse(this.title, this._event) {
    checkNotNull(title);
    checkNotNull(_event);
  }

  void trigger(Game game) {
    game.broadcast(_event);
    game.broadcast(new RemoveOption(this));
  }
}