part of august.modules;

class DialogModule implements ModuleDefinition, HasInterface {
  final name = 'Dialog';

  Dialog create(Once once, Every every, Emit emit, Map modules) {
    return new Dialog(once, every, emit);
  }

  DialogInterface createInterface(Dialog dialog, InterfaceEmit emit) {
    return new DialogInterface(dialog);
  }

  createInterfaceHandler(_) => new NoopInterfaceHandler();
}

class Dialog {
  final Once _once;
  final Every _every;
  final Emit _emit;

  Dialog(this._once, this._every, this._emit);

  Future<DialogEvent> add(String dialog,
          {String from, String to, Duration delay: Duration.ZERO}) =>
      _emit(new DialogEvent(dialog, from: from, to: to), delay: delay);

  Future<NarrationEvent> narrate(String narration,
          {Duration delay: Duration.ZERO}) =>
      _emit(new NarrationEvent(narration), delay: delay);

  Future<ClearDialogEvent> clear() => _emit(new ClearDialogEvent());

  Future<DialogEvent> once({String dialog, String from, String to}) {
    // TODO
    throw new UnimplementedError();
  }

  Stream<DialogEvent> get dialog => _every((e) => e is DialogEvent);

  Stream<NarrationEvent> get narration => _every((e) => e is NarrationEvent);

  Stream<ClearDialogEvent> get clears => _every((e) => e is ClearDialogEvent);
}

class DialogInterface {
  final Dialog _dialog;

  Stream<DialogEvent> get dialog => _dialog.dialog;

  Stream<NarrationEvent> get narration => _dialog.narration;

  Stream<ClearDialogEvent> get clears => _dialog.clears;

  DialogInterface(this._dialog);
}

// TODO: default aliases

class DialogEvent implements Event {
  final String alias;
  final String dialog;
  final String from;
  final String to;

  DialogEvent(this.dialog, {this.from, this.to, this.alias: ""});
}

class NarrationEvent implements Event {
  final String alias;
  final String narration;

  NarrationEvent(this.narration, {this.alias: ""});
}

class ClearDialogEvent implements Event {
  final String alias;

  ClearDialogEvent([this.alias = ""]);
}
