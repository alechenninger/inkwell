// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

part of august.ui;

class Ui extends Actor {
  final HtmlElement _container;

  Ui(this._container);

  @override
  void prepare(Game game) {
    game.on[DialogEvent]
        .listen((e) => new DialogElement(e, _container));
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
      ..classes.add('what')
      ..innerHtml = '${e.what}';

    var dialog = new DivElement()
      ..classes.add('dialog')
      ..children.addAll([speaker, target, what]);

    container.children.add(dialog);
  }
}

