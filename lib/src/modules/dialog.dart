part of august.modules;

class DialogModule implements ModuleDefinition, HasInterface {
  final name = 'Dialog';

  Dialog create(Run run, Map modules) {
    return new Dialog(run);
  }

  DialogInterface createInterface(Dialog dialog, InterfaceEmit emit) {
    return new DialogInterface(dialog);
  }

  createInterfaceHandler(_) => new NoopInterfaceHandler();
}

class Dialog {
  final Run _run;

  Dialog(this._run);

  Future<DialogEvent> add(String dialog,
          {String from,
          String to,
          Duration delay: Duration.ZERO,
          Replies replies: const Replies.none()}) =>
      _run.emit(new DialogEvent(dialog, from: from, to: to, replies: replies),
          delay: delay);

  Future<NarrationEvent> narrate(String narration,
          {Duration delay: Duration.ZERO}) =>
      _run.emit(new NarrationEvent(narration), delay: delay);

  Future<ClearDialogEvent> clear() => _run.emit(new ClearDialogEvent());

  Future<DialogEvent> once({String dialog, String from, String to}) =>
      _run.once((e) => e is DialogEvent &&
          e.dialog == dialog &&
          e.from == from &&
          e.to == to);

  Stream<DialogEvent> get dialog => _run.every((e) => e is DialogEvent);

  Stream<NarrationEvent> get narration =>
      _run.every((e) => e is NarrationEvent);

  Stream<ClearDialogEvent> get clears =>
      _run.every((e) => e is ClearDialogEvent);
}

class DialogInterface {
  final Dialog _dialog;

  Stream<DialogEvent> get dialog => _dialog.dialog;

  Stream<NarrationEvent> get narration => _dialog.narration;

  Stream<ClearDialogEvent> get clears => _dialog.clears;

  DialogInterface(this._dialog);
}

class DialogEvent {
  final String alias;
  final String dialog;
  final String from;
  final String to;
  final Replies replies;

  DialogEvent(String dialog,
      {String from,
      String to,
      String alias,
      Replies replies: const Replies.none()})
      : this.dialog = dialog,
        this.from = from,
        this.to = to,
        this.replies = replies,
        this.alias = alias == null
            ? "From: $from, To: $to, Dialog: $dialog, Replies: $replies"
            : alias;

  toString() => alias;
}

class Replies {
  final bool modal;
  final List<String> replies;

  Replies(this.replies, {this.modal: false});

  const Replies.none()
      : modal = false,
        replies = const [];

  toString() => "Replies: $replies, Modal: $modal";
}

class NarrationEvent {
  final String alias;
  final String narration;

  NarrationEvent(String narration, {String alias})
      : this.narration = narration,
        this.alias = alias == null ? "Narration: $narration" : alias;

  toString() => alias;
}

class ClearDialogEvent {
  final String alias;

  ClearDialogEvent([this.alias = "Dialog clear"]);

  toString() => alias;
}
