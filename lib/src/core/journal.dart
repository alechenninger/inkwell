// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

class Journal {
  final List<Event> _journal = new List();

  Journal(Game game, {shouldLog: false}) {
    game.stream.listen(_journal.add);

    if (shouldLog) {
      game.stream.listen(print);
    }
  }

  /// Takes a snapshot copy of the current journal.
  List<Event> toList() => new List.from(_journal);
}
