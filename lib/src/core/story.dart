// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

/// A collection of [Actor]s sharing a single [Game].
class Story {
  final Game _game;
  final List<Actor> _actors;

  Story(this._actors, [Game director]):
    this._game = director != null ? director : new Game() {
    _actors.forEach((a) {
      a.prepare(_game);

      _game.on[BeginEvent].listen((e) => a.action(_game));
    });
  }

  /// Broadcasts the [BeginEvent].
  void begin() {
    _game.begin();
  }
}