// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

abstract class Actor {
  /// Called before [onBegin]. Use to register event handlers prior to the start
  /// of the [Game]. Broadcasting events from [beforeBegin] is considered an error.
  beforeBegin(Game game);

  /// > Lights, camera... action!
  ///
  /// Called when the [Game] begins. By default, does nothing. Some [Actor]s
  /// may want to broadcast [Event]s. [Event] listeners should be registered
  /// in [beforeBegin].
  ///
  /// If an actor is added to a game after it has already begun, onBegin is
  /// called immediately.
  onBegin(Game game) {}

  String toString() => this.runtimeType.toString();
}

class Inventory {
  final Map<Item, int> _items = {};

  add(Item item, [int qty = 1]) {
    int currentQty = _items[item];

    if (currentQty == null) {
      currentQty = 0;
    }

    int newQty = currentQty + qty;

    if (newQty > 0) {
      _items[item] = newQty;
    } else {
      _items.remove(item);
    }
  }

  Item consume(item, [int qty = 1]) {
    int currentQty = _items[item];

    if (currentQty == null) {
      currentQty = 0;
    }

    int newQty = currentQty - qty;

    if (newQty > 0) {
      _items[item] = newQty;
    } else {
      _items.remove(item);
    }

    return item;
  }
}

class Item {

}
