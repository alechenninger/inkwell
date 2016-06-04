// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.dialog;

// import 'package:august/august.dart';

// import 'package:quiver/core.dart' as quiver show hash2, hashObjects;
// import 'package:collection/equality.dart';

class Dialog {}

// class DialogDefinition implements InterfaceModuleDefinition<Dialog> {
//   Dialog createModule(Run run, Map modules) {
//     return new Dialog(run);
//   }
//
//   DialogInterface createInterface(Dialog dialog, InterfaceEmit emit) {
//     return new DialogInterface(dialog, emit);
//   }
//
//   DialogInterfaceHandler createInterfaceHandler(Dialog dialog) {
//     return new DialogInterfaceHandler(dialog);
//   }
// }
//
// class Dialog {
//   final Run _run;
//
//   final List<DialogEvent> _alreadyReplied = [];
//
//   Dialog(this._run);
//
//   Future<DialogEvent> add(String dialog,
//       {String from,
//       String to,
//       String named,
//       Duration delay: Duration.ZERO,
//       Replies replies: const _NoReplies()}) {
//     var event = new DialogEvent(dialog,
//         from: from, to: to, replies: replies, name: named);
//
//     if (_previousDialogNames.contains(event.name)) {
//       throw new ArgumentError("Added dialog names must be unique. Dialog names "
//           "are useful as a way to distinguish otherwise similar dialogs. "
//           "Note that if you did not provide a name explicitly, it was computed "
//           "from the dialogs other attributes, and must still be unique. "
//           "By enforcing a name's uniqueness, you can rely on referring to a "
//           "dialog's name as only ever referring to the one dialog you mean it "
//           "to. Dialog added was: $event.");
//     }
//
//     _previousDialogNames.add(event.name);
//
//     if (replies.modal) {
//       // TODO: rework this
//     }
//
//     return _run.emit(event, delay: delay);
//   }
//
//   Future<ReplyEvent> reply(String reply, DialogEvent dialogEvent) {
//     if (_alreadyReplied.contains(dialogEvent)) {
//       throw new StateError("Cannot reply to a dialog more than once. Tried to "
//           "reply twice to $dialogEvent.");
//     }
//
//     _alreadyReplied.add(dialogEvent);
//
//     return _run.emit(new ReplyEvent(reply, dialogEvent));
//   }
//
//   Future<NarrationEvent> narrate(String narration,
//           {Duration delay: Duration.ZERO}) =>
//       _run.emit(new NarrationEvent(narration), delay: delay);
//
//   Future<ClearDialogEvent> clear() {
//     _alreadyReplied.clear();
//     return _run.emit(new ClearDialogEvent());
//   }
//
//   /// Listens for next emitted dialog which matches the provided criteria.
//   ///
//   /// [named] criteria trumps all others.
//   Future<DialogEvent> once(
//       {String dialog, String from, String to, String named}) {
//     if (_notNull(named)) {
//       return this.dialog.firstWhere((e) => e.name == named);
//     }
//
//     var conditions = [];
//
//     if (_notNull(dialog)) conditions.add((e) => e.dialog == dialog);
//     if (_notNull(from)) conditions.add((e) => e.from = from);
//     if (_notNull(to)) conditions.add((e) => e.to == to);
//
//     return this.dialog.firstWhere((e) => conditions.every((c) => c(e)));
//   }
//
//   Future<ReplyEvent> onceReply(
//       {String reply,
//       String forDialog,
//       String forDialogTo,
//       String forDialogFrom,
//       String forDialogNamed}) {
//     var conditions = [];
//
//     if (_notNull(reply)) {
//       conditions.add((e) => e.reply == reply);
//     }
//
//     if (_notNull(forDialogNamed)) {
//       conditions.add((e) => e.dialogEvent.name == forDialogNamed);
//     } else {
//       if (_notNull(forDialog)) {
//         conditions.add((e) => e.dialogEvent.dialog == forDialog);
//       }
//
//       if (_notNull(forDialogTo)) {
//         conditions.add((e) => e.dialogEvent.to == forDialogTo);
//       }
//
//       if (_notNull(forDialogFrom)) {
//         conditions.add((e) => e.dialogEvent.from == forDialogFrom);
//       }
//
//       if (conditions.isEmpty) {
//         throw new ArgumentError("Must pass at least one criteria for a reply.");
//       }
//     }
//
//     return replies.firstWhere((e) => conditions.every((c) => c(e)));
//   }
//
//   Stream<DialogEvent> get dialog => _run.every((e) => e is DialogEvent);
//
//   Stream<ReplyEvent> get replies => _run.every((e) => e is ReplyEvent);
//
//   Stream<NarrationEvent> get narration =>
//       _run.every((e) => e is NarrationEvent);
//
//   Stream<ClearDialogEvent> get clears =>
//       _run.every((e) => e is ClearDialogEvent);
// }
//
// class DialogInterface implements Interface {
//   final Dialog _dialog;
//   final InterfaceEmit _emit;
//
//   Stream<DialogEvent> get dialog => _dialog.dialog;
//
//   Stream<ReplyEvent> get replies => _dialog.replies;
//
//   Stream<NarrationEvent> get narration => _dialog.narration;
//
//   Stream<ClearDialogEvent> get clears => _dialog.clears;
//
//   DialogInterface(this._dialog, this._emit);
//
//   void reply(String reply, DialogEvent dialogEvent) {
//     _emit('reply', {'reply': reply, 'dialogEvent': dialogEvent.toJson()});
//   }
// }
//
// class DialogInterfaceHandler implements InterfaceHandler {
//   final Dialog _dialog;
//
//   DialogInterfaceHandler(this._dialog);
//
//   void handle(String action, Map args) {
//     switch (action) {
//       case 'reply':
//         _dialog.reply(
//             args['reply'], new DialogEvent.fromJson(args['dialogEvent']));
//     }
//   }
// }
//
// class DialogEvent {
//   final String name;
//   final String dialog;
//   final String from;
//   final String to;
//   final Replies replies;
//
//   DialogEvent(String dialog,
//       {String from: "",
//       String to: "",
//       String name,
//       Replies replies: const _NoReplies()})
//       : this.dialog = dialog,
//         this.from = from,
//         this.to = to,
//         this.replies = replies,
//         this.name = name == null
//             ? "From: $from, To: $to, Dialog: $dialog, Replies: $replies"
//             : name;
//
//   DialogEvent.fromJson(Map json)
//       : name = json['name'],
//         dialog = json['dialog'],
//         from = json['from'],
//         to = json['to'],
//         replies = new Replies.fromJson(json['replies']);
//
//   toString() => name;
//
//   Map toJson() => {
//         'name': name,
//         'dialog': dialog,
//         'from': from,
//         'to': to,
//         'replies': replies.toJson()
//       };
//
//   bool operator ==(dynamic other) => other is DialogEvent &&
//       name == other.name &&
//       dialog == other.dialog &&
//       from == other.from &&
//       to == other.to &&
//       replies == other.replies;
//
//   int get hashCode => quiver.hashObjects([name, dialog, from, to, replies]);
// }
//
// class Replies {
//   final bool modal;
//   final List<String> available;
//
//   Replies(this.available, {this.modal: false});
//
//   Replies.fromJson(Map json)
//       : modal = json['modal'],
//         available = json['replies'];
//
//   toString() => "Replies: $available, Modal: $modal";
//
//   Map toJson() => {'modal': modal, 'replies': available};
//
//   bool operator ==(dynamic other) => other is Replies &&
//       modal == other.modal &&
//       const IterableEquality().equals(available, other.available);
//
//   int get hashCode => quiver.hash2(modal, available);
// }
//
// class NarrationEvent {
//   final String alias;
//   final String narration;
//
//   NarrationEvent(String narration, {String alias})
//       : this.narration = narration,
//         this.alias = alias == null ? "Narration: $narration" : alias;
//
//   toString() => alias;
// }
//
// class ClearDialogEvent {
//   final String alias;
//
//   ClearDialogEvent([this.alias = "Dialog clear"]);
//
//   toString() => alias;
// }
//
// class ReplyEvent {
//   final DialogEvent dialogEvent;
//   final String reply;
//
//   ReplyEvent(this.reply, this.dialogEvent);
//
//   toString() => "Reply: $reply, dialog: $dialogEvent";
// }
//
// class _NoReplies implements Replies {
//   final bool modal = false;
//   final List<String> available = const [];
//
//   const _NoReplies();
//
//   toString() => "Replies: $available, Modal: $modal";
//
//   Map toJson() => {'modal': modal, 'replies': available};
// }
//
// final List<String> _previousDialogNames = <String>[];
//
// bool _notNull(dynamic it) => it != null;
