part of august.html;

class HtmlPersistence implements Persistence {
  final String _scriptHandle;
  List<InterfaceEvent> _savedEvents;

  HtmlPersistence(Script script, [Storage _storage])
      : _scriptHandle = script.name + script.version {
    var storage = _storage == null ? window.localStorage : _storage;

    if (storage.containsKey(_scriptHandle)) {
      var saved = JSON.decode(storage[_scriptHandle]);
      _savedEvents = saved.map((o) => new InterfaceEvent.fromJson(o));
      print("Loaded $_savedEvents");
    } else {
      _savedEvents = [];
    }

    window.onBeforeUnload.listen((e) {
      storage[_scriptHandle] = JSON.encode(_savedEvents);
    });
  }

  void saveEvent(InterfaceEvent event) {
    _savedEvents.add(event);
  }

  List<InterfaceEvent> get savedEvents => new List.from(_savedEvents);
}
