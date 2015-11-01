// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.html;

/// Quick hacked together UI
class SimpleHtmlUi {
  final HtmlElement _container;
  final HtmlElement _dialogContainer = new DivElement()..classes.add('dialogs');
  final HtmlElement _optionsContainer = new UListElement()
    ..classes.add('options');

  static CreateUi forContainer(HtmlElement container) => (interfaces) =>
      new SimpleHtmlUi(container, interfaces[Options], interfaces[Dialog]);

  SimpleHtmlUi(
      this._container, OptionsInterface options, DialogInterface dialog) {
    _container.children.addAll([_optionsContainer, _dialogContainer]);

    // TODO: Add options and dialog already present

    dialog.dialog.listen(
        (e) => _dialogContainer.children.add(_getDialogElement(e, dialog)));

    dialog.narration
        .listen((e) => _dialogContainer.children.add(new DivElement()
          ..classes.add('narration')
          ..innerHtml = e.narration));

    dialog.clears.listen((e) {
      _dialogContainer.children.clear();
    });

    options.additions.listen((o) {
      _optionsContainer.children
          .add(new LIElement()..children.add(new SpanElement()
            ..classes.add('option')
            ..attributes['name'] = o.name
            ..innerHtml = o.text
            ..onClick.listen((e) => options.use(o.name))));
    });

    options.removals.listen((o) {
      _optionsContainer.children
          .removeWhere((e) => e.children[0].attributes['name'] == o);
    });

    options.uses.listen((o) {
      _optionsContainer.children
          .removeWhere((e) => e.children[0].attributes['name'] == o);
    });
  }
}

DivElement _getDialogElement(DialogEvent e, DialogInterface dialog) {
  var dialogElement = new DivElement()
    ..classes.add('dialog')
    ..id = _toId(e.name);

  dialogElement.children.add(new DivElement()
    ..classes.add('what')
    ..innerHtml = '${e.dialog}');

  if (e.to != null) {
    dialogElement.children.insert(0, new DivElement()
      ..classes.add('target')
      ..innerHtml = "${e.to}");
  }

  if (e.from != null) {
    dialogElement.children.insert(0, new DivElement()
      ..classes.add('speaker')
      ..innerHtml = e.to == null ? e.from : "${e.from} to...");
  }

  if (e.replies.available.isNotEmpty) {
    var replied = false;

    Iterable<DivElement> replies =
        e.replies.available.map((r) => new LIElement()
          ..children.add(new SpanElement()
            ..classes.addAll(['reply', 'reply-available'])
            ..innerHtml = r
            ..onClick.first.then((clickEvent) {
              if (!replied) dialog.reply(r, e);
            })));

    dialog.replies
        .firstWhere((r) => r.dialogEvent.name == e.name)
        .then((ReplyEvent r) {
      replied = true;

      for (var replyElement
          in querySelectorAll("#${_toId(e.name)} .reply-available")) {
        replyElement.classes.remove('reply-available');

        if (replyElement.innerHtml == r.reply) {
          replyElement.classes.add('reply-chosen');
        } else {
          replyElement.classes.add('reply-not-chosen');
        }
      }
    });

    dialogElement.children.add(new UListElement()
      ..classes.add('replies')
      ..children.addAll(replies));
  }

  return dialogElement;
}

String _toId(String name) {
  return name.replaceAll(new RegExp("[ :\\[\\],\\?\\.!']"), '_');
}
