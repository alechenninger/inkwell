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

    // TODO: Add options and dialog already present

    dialog.dialog.listen((e) => new DialogElement(e, _mainPanel, dialog));

    dialog.clears.listen((e) {
      _mainPanel.children.clear();
    });

    options.additions.listen((o) {
      _optionsPanel.children.add(new DivElement()
        ..classes.add('option')
        ..innerHtml = o.text
        ..onClick.listen((e) => options.use(o.name)));
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
  DialogElement(DialogEvent e, HtmlElement container, DialogInterface dialog) {
    var speaker = new DivElement()
      ..classes.add('speaker')
      ..innerHtml = "${e.from}";

    var target = new DivElement()
      ..classes.add('target')
      ..innerHtml = "${e.to}";

    var what = new DivElement()
      ..classes.add('what')
      ..innerHtml = '${e.dialog}';

    var replied = false;

    var replies = e.replies.available.map((r) => new DivElement()
      ..classes.add('reply')
      ..innerHtml = r
      ..onClick.first.then((_) {
        if (!replied) dialog.reply(r, e);
      }));

    dialog.replies
        .firstWhere((r) => r.dialogEvent == e)
        .then((_) => replied = true);

    var replyContainer = new DivElement()
      ..classes.add('replies')
      ..children.addAll(replies);

    var dialogElement = new DivElement()
      ..classes.add('dialog')
      ..children.addAll([speaker, target, what, replyContainer]);

    container.children.add(dialogElement);
  }
}
