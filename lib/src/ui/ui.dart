// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.ui;

class SimpleHtmlUi extends ActorSupport {
  final HtmlElement _container;
  final HtmlElement _mainPanel = new DivElement()..classes.add('event-panel');

  final HtmlElement _optionsPanel = new DivElement()
    ..classes.add('options-panel');

  final List<DialogEvent> _dialog = [];
  final List<Option> _options = [];

  SimpleHtmlUi(this._container, Script script, Game game, [Map json])
      : super(game) {
    _container.children.addAll([_mainPanel, _optionsPanel]);

    if (json != null) {
      json["dialog"]
          .map((d) => new DialogEvent.fromJson(d))
          .forEach(_addDialog);
      json["options"]
          .map((o) => new AddOption.fromJson(o, script))
          .forEach(_addOption);
    }
  }

  @override
  Map<String, Listener> get listeners => {
    "addDialog": _addDialog,
    "addOption": _addOption,
    "removeOption": _removeOption
  };

  @override
  void onBegin() {
    on(DialogEvent)
      ..persistently()
      ..listen("addDialog");
    on(AddOption)
      ..persistently()
      ..listen("addOption");
    on(RemoveOption)
      ..persistently()
      ..listen("removeOption");
  }

  _addOption(AddOption e) {
    _options.add(e.option);
    new OptionElement(e.option, broadcast, _optionsPanel);
  }

  _addDialog(DialogEvent e) {
    _dialog.add(e);
    new DialogElement(e, _mainPanel);
  }

  _removeOption(RemoveOption e) {
    _options.removeWhere((o) => o.title == e.option.title);
    _optionsPanel.children.removeWhere((c) => c.innerHtml == e.option.title);
  }

  Map toJson() => {"options": _options, "dialog": _dialog};
}

class DialogElement {
  DialogElement(DialogEvent e, HtmlElement container) {
    var speaker = new DivElement()
      ..classes.add('speaker')
      ..innerHtml = "${e.speaker}";

    var target = new DivElement()
      ..classes.add('target')
      ..innerHtml = "${e.target}";

    var what = new DivElement()
      ..classes.add('dialog-text')
      ..innerHtml = '${e.dialog}';

    var dialog = new DivElement()
      ..classes.add('dialog')
      ..children.addAll([speaker, target, what]);

    container.children.add(dialog);
  }
}

//class ModalDialogElement {
//  ModalDialogElement(ModalDialogEvent e, Game game, HtmlElement container) {
//    var speaker = new DivElement()
//      ..classes.add('speaker')
//      ..innerHtml = "${e.speaker}";
//
//    var target = new DivElement()
//      ..classes.add('target')
//      ..innerHtml = "${e.target}";
//
//    var what = new DivElement()
//      ..classes.add('what')
//      ..innerHtml = '${e.what}';
//
//    var replies = e.replies.map((r) => new DivElement()
//      ..classes.add('reply')
//      ..innerHtml = '${r.title}'
//      ..onClick.first.then((e) => game.broadcast(r.event)));
//
//    var replyContainer = new DivElement()
//      ..classes.add('replies')
//      ..children.addAll(replies);
//
//    var dialog = new DivElement()
//      ..classes.add('dialog')
//      ..children.addAll([speaker, target, what, replyContainer]);
//
//    container.children.add(dialog);
//  }
//}

class OptionElement {
  OptionElement(Option o, void broadcast(Event e), HtmlElement container) {
    container.children.add(new DivElement()
      ..classes.add('option')
      ..innerHtml = o.title
      ..onClick.listen((e) => o.trigger(broadcast)));
  }
}
