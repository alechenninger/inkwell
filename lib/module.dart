import 'package:august/august.dart';
import 'package:rxdart/rxdart.dart';
import 'dart:math';

import 'input.dart';
import 'src/events.dart';

abstract class Module {
  Stream<Event> get events;
}

void server() {
  Stream<Action<Items>> itemActions; // get from clients
  var items = Items();
  var clientEvents = StreamController<Event>();

  itemActions.listen((a) => a.run(items));
  items.events.pipe(clientEvents);
}

void client() {
  Stream<Event> events; // get from server
  var actions = StreamController<Action<dynamic>>(); // send to server
  var ui; // some ui impl
  ui.listen(events);
  ui.actions.pipe(actions);
}


abstract class Actionable<T> {
  //Action<M> get asAction;
  Future<T> perform(); // Accept arg? could be void or optional
  Scope get availability;
//  Scope get visibility;
}

abstract class Inputable<T, I> {
  Future<T> input(I input);
  Scope get availability;
}

//abstract class Identifiable {
//  Id get id;
//}
//
//class Performed<T extends Actionable> extends Event {
//  final Id id;
//
//  Performed(this.id);
//}
//
//class Inputted<T extends Inputable<dynamic, I>, I> {
//  final Id id;
//  final I input;
//
//  Inputted(this.id, this.input);
//}

//mixin Counted<T, M> on Actionable<T> {
//  CountScope get uses;
//  Scope _availability;
//  Scope get availability =>
//      _availability ?? (_availability = super.availability.and(uses));
//  Future<T> perform() async {
//    var answer = await super.perform();
//    uses.increment();
//    return answer;
//  }
//}

class Items extends Module {
  final _uses = Events<ItemUsed>();

  final _items = <Id, Item>{};

  Stream<Event> get events => Rx.merge([uses]);

  Item addItem(String name, {Scope available}) {
    var it = Item(name, this);
    available.onEnter.listen((_) {});
    return it;
  }

  Stream<ItemUsed> get uses => _uses.stream;

  Stream<String> onItem;
}

class ItemUsed extends Event {
  final String name;

  ItemUsed(this.name);
}

class Item {
  final Id id = Id();
  final String name;
  final Items _items;

  Item(this.name, this._items);

  Future<ItemUsed> use() async {
    return _items._uses.event(() {
      if (_items._items.remove(id) != null) {
        throw StateError('No item found named $name');
      }

      return ItemUsed(name);
    });
  }
}

class ItemAvailable extends Event {

}

class UseItem extends Action<Items> {
  final String moduleName = '$Items';
  final String name = '$UseItem';
  final Map<String, dynamic> parameters;

  UseItem(String name) : parameters = {'name': name};

  @override
  void run(Items items) {
    items._items[Id.of(parameters['id'] as String)]?.use();
  }
}

