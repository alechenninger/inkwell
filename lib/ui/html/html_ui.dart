// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:html';
import 'dart:collection';

import 'package:august/options.dart';
import 'package:august/dialog.dart';

/// Quick hacked together UI
class SimpleHtmlUi {
  final HtmlElement _container;
  final HtmlElement _dialogContainer = new DivElement()..classes.add('dialog');
  final HtmlElement _optionsContainer = new UListElement()
    ..classes.add('options');

  var _domQueue = new Queue<Function>();

  SimpleHtmlUi(this._container, OptionsUi options, DialogUi dialog) {
    _container.children.addAll([_optionsContainer, _dialogContainer]);

    // TODO: Add options and dialog already present

    dialog.onAdd.listen((speech) {
      var speechElement = new DivElement()..classes.add('speech');

      _beforeNextPaint(() {
        _dialogContainer.children.add(speechElement);
      });

      speechElement.children.add(new DivElement()
        ..classes.add('what')
        ..innerHtml = '${speech.markup}');

      if (speech.target != null) {
        speechElement.children.insert(
            0,
            new DivElement()
              ..classes.add('target')
              ..innerHtml = "${speech.target}");
      }

      if (speech.speaker != null) {
        speechElement.children.insert(
            0,
            new DivElement()
              ..classes.add('speaker')
              ..innerHtml = speech.target == null
                  ? speech.speaker
                  : "${speech.speaker} to...");
      }

      speech.onRemove.listen((_) => speechElement.remove());

      UListElement repliesElement = null;

      speech.onReplyAvailable.listen((reply) {
        if (repliesElement == null) {
          repliesElement = new UListElement()..classes.add('replies');
          speechElement.children.add(repliesElement);
        }

        var replyElement = new LIElement()
          ..children.add(new SpanElement()
            ..classes.addAll(['reply', 'reply-available'])
            ..innerHtml = reply.markup
            ..onClick.listen((_) => reply.use()));

        repliesElement.children.add(replyElement);

        // TODO consider alternate behavior vs used and removed vs just removed
        // vs unavailable due to exclusive reply use
        reply.onRemove.listen((_) => replyElement.remove());
      });
    });

    options.onOptionAvailable.listen((o) {
      var optionElement = new LIElement()
        ..children.add(new SpanElement()
          ..classes.add('option')
          ..innerHtml = o.text
          ..onClick.listen((_) => o.use()));

      _beforeNextPaint(() {
        _optionsContainer.children.add(optionElement);
      });

      o.onUnavailable.first.then((_) {
        _beforeNextPaint(() {
          optionElement.remove();
        });
      });
    });
  }

  // TODO: not sure if this is really helping anything
  _beforeNextPaint(void domUpdate()) {
    _domQueue.add(domUpdate);
    window.animationFrame.then((_) {
      while (_domQueue.isNotEmpty) {
        _domQueue.removeFirst()();
      }
    });
  }
}
