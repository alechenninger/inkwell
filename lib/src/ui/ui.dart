// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.ui;

abstract class Ui {
  void listenTo(Stream<Event> events, void broadcast(Event event));
}

class SimpleHtmlUi implements Ui {
  final HtmlElement _container;
  final HtmlElement _mainPanel = new DivElement()..classes.add('event-panel');

  final HtmlElement _optionsPanel = new DivElement()
    ..classes.add('options-panel');

  final List<Option> options = [];

  SimpleHtmlUi(this._container) {
    _container.children.addAll([_mainPanel, _optionsPanel]);
  }

  void listenTo(Stream<Event> events, void broadcast(Event event)) {
    events
        .where((e) => e is DialogEvent)
        .listen((e) => new DialogElement(e, _mainPanel));

    events
        .where((e) => e is AddOption)
        .listen((e) => new OptionElement(e.option, broadcast, _optionsPanel));

    events.where((e) => e is RemoveOption).listen((e) => _optionsPanel.children
        .removeWhere((c) => c.innerHtml == e.option.title));

//    game.on[ModalDialogEvent]
//        .listen((e) => new ModalDialogElement(e, game, _mainPanel));
  }
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
      ..classes.add('dialog')
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
