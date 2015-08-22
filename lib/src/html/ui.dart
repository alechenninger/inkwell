// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.html;

/// Quick hacked together UI
class SimpleHtmlUi {
  final HtmlElement _container;
  final HtmlElement _mainPanel = new DivElement()..classes.add('event-panel');

  final HtmlElement _optionsPanel = new DivElement()
    ..classes.add('options-panel');

  static CreateUi forContainer(HtmlElement container) => (interfaces) =>
      new SimpleHtmlUi(container, interfaces[Options], interfaces[Dialog]);

  SimpleHtmlUi(
      this._container, OptionsInterface options, DialogInterface dialog) {
    _container.children.addAll([_mainPanel, _optionsPanel]);

    // TODO: Add options and dialog already present?

    dialog.dialog.listen((e) => new DialogElement(e, _mainPanel));

    dialog.clears.listen((e) {
      _mainPanel.children.clear();
    });

    options.additions.listen((o) {
      _optionsPanel.children.add(new DivElement()
        ..classes.add('option')
        ..innerHtml = o
        ..onClick.listen((_) => options.use(o)));
    });

    options.removals.listen((o) {
      _optionsPanel.children.removeWhere((e) => e.innerHtml == o);
    });

    options.uses.listen((o) {
      _optionsPanel.children.removeWhere((e) => e.innerHtml == o);
    });
  }
}

class DialogElement {
  DialogElement(DialogEvent e, HtmlElement container) {
    var speaker = new DivElement()
      ..classes.add('speaker')
      ..innerHtml = "${e.from}";

    var target = new DivElement()
      ..classes.add('target')
      ..innerHtml = "${e.to}";

    var what = new DivElement()
      ..classes.add('what')
      ..innerHtml = '${e.dialog}';

    var dialog = new DivElement()
      ..classes.add('dialog')
      ..children.addAll([speaker, target, what]);

    container.children.add(dialog);
  }
}

// class ModalDialogElement {
//   ModalDialogElement(ModalDialogEvent e, Game game, HtmlElement container) {
//     var speaker = new DivElement()
//       ..classes.add('speaker')
//       ..innerHtml = "${e.speaker}";
//
//     var target = new DivElement()
//       ..classes.add('target')
//       ..innerHtml = "${e.target}";
//
//     var what = new DivElement()
//       ..classes.add('what')
//       ..innerHtml = '${e.what}';
//
//     var replies = e.replies.map((r) => new DivElement()
//       ..classes.add('reply')
//       ..innerHtml = '${r.title}'
//       ..onClick.first.then((e) => game.broadcast(r.event)));
//
//     var replyContainer = new DivElement()
//       ..classes.add('replies')
//       ..children.addAll(replies);
//
//     var dialog = new DivElement()
//       ..classes.add('dialog')
//       ..children.addAll([speaker, target, what, replyContainer]);
//
//     container.children.add(dialog);
//   }
// }
