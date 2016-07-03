// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:august/august.dart';

class Dialog {
  final _dialogs = new StreamController<Speech>.broadcast(sync: true);

  // TODO: figure out defaults
  Speech narrate(String markup, {Scope scope}) {
    var narration = new Speech(markup, scope, '', '');
    narration._scope.onEnter.listen((_) => _dialogs.add(narration));
    return narration;
  }

  // TODO: figure out default
  Speech add(String markup,
      {String speaker: '', String target: '', Scope scope}) {
    var dialog = new Speech(markup, scope, speaker, target);
    dialog._scope.onEnter.listen((_) => _dialogs.add(dialog));
    return dialog;
  }

  Voice voice({String name: ''}) => new Voice(name, this);

  Stream<Speech> get _onAddDialog => _dialogs.stream;
}

class Voice {
  String name;

  final Dialog _dialogs;

  Voice(this.name, this._dialogs);

  Speech say(String markup, {String target, Scope scope}) =>
      _dialogs.add(markup, speaker: name, target: target, scope: scope);
}

class Speech {
  final String _markup;
  final Scope _scope;
  final String _speaker;
  final String _target;

  final _replies = new StreamController<Reply>.broadcast(sync: true);

  Speech(this._markup, this._scope, this._speaker, this._target);

  Reply addReply(String markup, {Scope scope: const Always()}) {
    var reply = new Reply(this, markup, scope);
    reply.availability.onEnter.listen((_) => _replies.add(reply));
    return reply;
  }

  Stream<Speech> get _onRemove => _scope.onExit.map((_) => this);
  Stream<Reply> get _onReplyAvailable => _replies.stream;
}

class Reply {
  final Speech dialog;
  final String _markup;
  final _uses = new StreamController.broadcast(sync: true);

  final _hasUses = new SettableScope.entered();
  ScopeAsValue _available;

  Scope<StateChangeEvent<bool>> get availability => _available.asScope;

  bool get isAvailable => _available.observed.value;

  bool get willBeAvailable => _available.observed.nextValue;

  Stream get onUse => _uses.stream;

  Reply(this.dialog, this._markup, Scope scope) {
    _available = new ScopeAsValue(owner: this)
      ..within(new AndScope(_hasUses, scope));
  }

  Future use() {
    if (_available.observed.nextValue == false) {
      return new Future.error(new ReplyNotAvailableException(this));
    }

    _hasUses.exit(null);

    return new Future(() {
      var event = new UseReplyEvent(this);
      _uses.add(event);
      return event;
    });
  }
}

class DialogUi {
  final Dialog _dialogs;
  final Sink<Interaction> _interactions;

  DialogUi(this._dialogs, this._interactions);

  Stream<UiSpeech> get onAdd =>
      _dialogs._onAddDialog.map((d) => new UiSpeech(d, _interactions));
}

class UiSpeech {
  final Speech _dialog;
  final Sink<Interaction> _interactions;

  UiSpeech(this._dialog, this._interactions);

  Stream<UiSpeech> get onRemove => _dialog._onRemove.map((_) => this);
  Stream<UiReply> get onReplyAvailable =>
      _dialog._onReplyAvailable.map((r) => new UiReply(r, _interactions));
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
  Map<String, dynamic> get parameters => {
        'dialog': {'markup': _reply.dialog._markup},
        'markup': _reply._markup
      };
}

class ReplyNotAvailableException implements Exception {
  final Reply reply;

  ReplyNotAvailableException(this.reply);
}

class UseReplyEvent {
  final Reply reply;

  UseReplyEvent(this.reply);
}
