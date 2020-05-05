import 'package:august/august.dart';
import 'package:rxdart/rxdart.dart';

import 'ui.dart';
import 'input.dart';
import 'src/events.dart';

abstract class Module<T> {
  dynamic ui(Stream<Event> events, StreamSink<Action<T>> actionSink);
  T controller(Stream<Action<T>> actions, StreamSink<Event> eventSink);
}

typedef ModuleFactory = T Function<T extends Test>(Stream<Action<T>>);

abstract class Test {
  Stream<Event> get events;
}

void test() {
  var m = ItemModule();
  var actions = StreamController<Action<Items>>();
  var events = StreamController<Event>();

  var items = m.controller(actions.stream, events);
  var itemsUi = m.ui(events.stream, actions);
}

void initController<T>(T controller, List<Stream<Event>> eventStreams,
    Stream<Action<T>> actions, StreamSink<Event> eventSink) {
  actions.listen((a) => a.run(controller));
  Rx.merge(eventStreams).pipe(eventSink);
}

class ItemModule implements Module<Items> {
  @override
  ItemUi ui(Stream<Event> events, StreamSink<Action<Items>> actionSink) =>
      ItemUi(events, actionSink);

  @override
  Items controller(
          Stream<Action<Items>> actions, StreamSink<Event> eventSink) =>
      Items(actions, eventSink);
}

class ItemUi {
  final Sink<Action<Items>> _actions;
  final Stream<Event> _events;

  ItemUi(this._events, this._actions);
}

class Items {
  final Stream<Action<Items>> _actions;
  final Events _uses = Events();

  final _items = <Item>[];

  Items(this._actions, StreamSink<Event> eventSink) {
    initController(this, [_uses.stream], _actions, eventSink);
  }

  Item addItem(String name, {Scope available}) {
    var it = Item(name, this);
    available.onEnter.listen((_) {});
    return it;
  }

  Stream<ItemUsed> get uses =>
      _uses.stream.where((e) => e is ItemUsed).map((e) => e as ItemUsed);

  Stream<String> onItem;
}

class UiItem {
  final String name;
  final Stream<Event> _events;

  UiItem(this.name, this._events);

  Stream<ItemUsed> get uses =>
      _events.whereType<ItemUsed>().where((i) => i.name == name);
}

class ItemUsed extends Event {
  final String name;

  ItemUsed(this.name);
}

class Item {
  final String name;
  final Items _items;

  Item(this.name, this._items);

  Future<ItemUsed> use() async {
    return _items._uses.event(() {
      if (!_items._items.remove(name)) {
        throw StateError('No item found named $name');
      }

      return ItemUsed(name);
    });
  }
}

class UseItem extends Action<Items> {
  final String moduleName = '$Items';
  final String name = '$UseItem';
  final Map<String, dynamic> parameters;

  UseItem(String name) : parameters = {'name': name};

  @override
  void run(Items items) {
    items._items.firstWhere((i) => i.name == name)?.use();
  }
}
