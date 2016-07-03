// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:august/august.dart';

class Dialog {
  final _dialog = new StreamController<Speech>.broadcast(sync: true);

  // TODO: figure out defaults
  Speech narrate(String markup, {Scope scope}) {
    var narration = new Speech(markup, scope, '', '');
    narration._scope.onEnter.listen((_) => _dialog.add(narration));
    return narration;
  }

  // TODO: figure out default
  Speech add(String markup,
      {String speaker: '', String target: '', Scope scope}) {
    var speech = new Speech(markup, scope, speaker, target);
    speech._scope.onEnter.listen((_) => _dialog.add(speech));
    if (scope.isEntered) {
      _dialog.add(speech);
    }
    return speech;
  }

  Voice voice({String name: ''}) => new Voice(name, this);

  Stream<Speech> get _onAddSpeech => _dialog.stream;
}

class Voice {
  String name;

  final Dialog _dialog;

  Voice(this.name, this._dialog);

  Speech say(String markup, {String target, Scope scope}) =>
      _dialog.add(markup, speaker: name, target: target, scope: scope);
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
  final Speech speech;
  final String _markup;
  final _uses = new StreamController.broadcast(sync: true);

  final _hasUses = new SettableScope.entered();
  ScopeAsValue _available;

  Scope<StateChangeEvent<bool>> get availability => _available.asScope;

  bool get isAvailable => _available.observed.value;

  bool get willBeAvailable => _available.observed.nextValue;

  Stream get onUse => _uses.stream;

  Reply(this.speech, this._markup, Scope scope) {
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
  final Dialog _dialog;
  final Sink<Interaction> _interactions;

  DialogUi(this._dialog, this._interactions);

  Stream<UiSpeech> get onAdd =>
      _dialog._onAddSpeech.map((d) => new UiSpeech(d, _interactions));
}

class UiSpeech {
  final Speech _speech;
  final Sink<Interaction> _interactions;

  UiSpeech(this._speech, this._interactions);

  String get markup => _speech._markup;
  String get speaker => _speech._speaker;
  String get target => _speech._target;

  Stream<UiSpeech> get onRemove => _speech._onRemove.map((_) => this);
  Stream<UiReply> get onReplyAvailable =>
      _speech._onReplyAvailable.map((r) => new UiReply(r, _interactions));
}

class UiReply {
  final Reply _reply;
  final Sink<Interaction> _interactions;

  UiReply(this._reply, this._interactions);

  String get markup => _reply._markup;

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
        'speech': {'markup': _reply.speech._markup},
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
