// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:html';
import 'dart:collection';

import 'package:august/options.dart';
import 'package:august/dialog.dart';

/// Quick hacked together UI
class SimpleHtmlUi {
  final Element _container;
  final _dialogContainer = DivElement()..classes.add('dialog');
  final _optionsContainer = UListElement()
    ..classes.add('options');

  final _domQueue = Queue<Function>();

  SimpleHtmlUi(this._container, OptionsUi options, DialogUi dialog) {
    _container.children.addAll([_optionsContainer, _dialogContainer]);

    // TODO: Add options and dialog already present

    dialog.onAdd.listen((speech) {
      var speechElement = DivElement()..classes.add('speech');

      _beforeNextPaint(() {
        _dialogContainer.children.add(speechElement);
      });

      speechElement.children.add(DivElement()
        ..classes.add('what')
        ..innerHtml = '${speech.markup}');

      if (speech.target != null) {
        speechElement.children.insert(
            0,
            DivElement()
              ..classes.add('target')
              ..innerHtml = "${speech.target}");
      }

      if (speech.speaker != null) {
        speechElement.children.insert(
            0,
            DivElement()
              ..classes.add('speaker')
              ..innerHtml = speech.target == null
                  ? speech.speaker
                  : "${speech.speaker} to...");
      }

      speech.onRemove.listen((_) => _beforeNextPaint(speechElement.remove));

      UListElement repliesElement;

      speech.onReplyAvailable.listen((reply) {
        var replyElement = LIElement()
          ..children.add(SpanElement()
            ..classes.addAll(['reply', 'reply-available'])
            ..innerHtml = reply.markup
            ..onClick.listen((_) => reply.use()));

        if (repliesElement == null) {
          repliesElement = UListElement()..classes.add('replies');
          repliesElement.children.add(replyElement);
          _beforeNextPaint(() => speechElement.children.add(repliesElement));
        } else {
          _beforeNextPaint(() => repliesElement.children.add(replyElement));
        }

        // TODO consider alternate behavior vs used and removed vs just removed
        // vs unavailable due to exclusive reply use
        reply.onRemove.listen((_) => _beforeNextPaint(replyElement.remove));
      });
    });

    options.onOptionAvailable.listen((o) {
      var optionElement = LIElement()
        ..children.add(SpanElement()
          ..classes.add('option')
          ..innerHtml = o.text
          ..onClick.listen((_) => o.use()));

      _beforeNextPaint(() {
        _optionsContainer.children.add(optionElement);
      });

      o.onUnavailable.first.then((_) => _beforeNextPaint(optionElement.remove));
    });
  }

  // TODO: not sure if this is really helping anything
  void _beforeNextPaint(void Function() domUpdate) {
    if (_domQueue.isEmpty) {
      window.animationFrame.then((_) {
        while (_domQueue.isNotEmpty) {
          _domQueue.removeFirst().call();
        }
      });
    }
    _domQueue.add(domUpdate);
  }
}
