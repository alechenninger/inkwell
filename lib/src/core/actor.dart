// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.core;

abstract class Actor {
  /// Called before [action]. Use to register event handlers prior to the start
  /// of the [Story]. Broadcasting events from [prepare] is considered an error.
  void prepare(Game game);

  /// > Lights, camera... action!
  ///
  /// Called when the [Story] "starts". By default, does nothing. Some [Actor]s
  /// may want to broadcast [Event]s. [Event] listeners should be registered
  /// in [prepare].
  void action(Game game) {}
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
