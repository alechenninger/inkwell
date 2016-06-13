// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:august/august.dart';

abstract class Dialogs {
  Dialog narrate(String markup, {Scope scope});
  Dialog add(String markup, {String speaker, String target, Scope scope});
  Voice voice({String name});

  Stream<Dialog> get _onAddDialog;
}

abstract class Voice {
  void set name(String name);
  Dialog say(String markup, {String speaker, String target, Scope scope});
}

abstract class Dialog {
  Reply addReply(String markup, {Scope scope});

  Stream<Dialog> get _onRemove;
  Stream<Reply> get _onAddReply;
}

abstract class Reply {
  Stream get onUse;
}

class DialogUi {
  final Dialogs _dialogs;
  final Sink<Interaction> _interactions;

  DialogUi(this._dialogs, this._interactions);

  Stream<UiDialog> get onAdd =>
      _dialogs._onAddDialog.map((d) => new UiDialog(d, _interactions));
}

class UiDialog {
  final Dialog _dialog;
  final Sink<Interaction> _interactions;

  UiDialog(this._dialog, this._interactions);

  Stream<UiDialog> get onRemove => _dialog._onRemove.map((_) => this);
  Stream<UiReply> get onAddReply =>
      _dialog._onAddReply.map((r) => new UiReply(r, _interactions));
}

class UiReply {
  final Reply _reply;
  final Sink<Interaction> _interactions;

  UiReply(this._reply, this._interactions);

  Stream<UiReply> get onRemove => throw "not implemented";

  void use() {
    _interactions.add(new UseReplyAction(_reply));
  }
}

class UseReplyAction implements Interaction {
  final Reply _reply;

  UseReplyAction(this._reply);

  // TODO: implement moduleName
  @override
  String get moduleName => null;

  // TODO: implement name
  @override
  String get name => null;

  // TODO: implement parameters
  @override
  Map<String, dynamic> get parameters => null;
}
