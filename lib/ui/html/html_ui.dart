// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:html';

import 'package:august/dialog.dart';
import 'package:august/input.dart';
import 'package:august/options.dart';
import 'package:august/prompts.dart';
import 'package:rxdart/rxdart.dart';

/// Quick hacked together UI
class SimpleHtmlUi {
  final _dialogContainer = DivElement()..classes.add('dialog');
  final _optionsContainer = UListElement()..classes.add('options');

  final _domQueue = Queue<Function>();

  final _actions = StreamController();
  Stream<Action> get actions => null;

  SimpleHtmlUi.install(Element _container, Stream<Event> events) {
    _container.children.addAll([_optionsContainer, _dialogContainer]);

    events.whereType<SpeechAvailable>().listen((speech) {
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
              ..innerHtml = '${speech.target}');
      }

      if (speech.speaker != null) {
        speechElement.children.insert(
            0,
            DivElement()
              ..classes.add('speaker')
              ..innerHtml = speech.target == null
                  ? speech.speaker
                  : '${speech.speaker} to...');
      }

      UListElement repliesElement;

      var onReply = events
          .whereType<ReplyAvailable>()
          .where((r) =>
              r.speech.speaker == speech.speaker &&
              r.speech.markup == speech.markup)
          .listen((reply) {
        var replyElement = LIElement()
          ..children.add(SpanElement()
            ..classes.addAll(['reply', 'reply-available'])
            ..innerHtml = reply.markup
            ..onClick.listen(
                (_) => _actions.add(ReplyAction(reply.speech, reply.markup))));

        if (repliesElement == null) {
          repliesElement = UListElement()..classes.add('replies');
          repliesElement.children.add(replyElement);
          _beforeNextPaint(() => speechElement.children.add(repliesElement));
        } else {
          _beforeNextPaint(() => repliesElement.children.add(replyElement));
        }

        events
            .whereType<ReplyUnavailable>()
            .firstWhere((r) =>
                r.speech.speaker == speech.speaker &&
                r.speech.markup == speech.markup)
            .then(
                // TODO consider alternate behavior vs used and removed vs just removed
                // vs unavailable due to exclusive reply use
                (_) => _beforeNextPaint(replyElement.remove));
      });

      events
          .whereType<SpeechUnavailable>()
          .firstWhere(
              (s) => s.markup == speech.markup && s.speaker == speech.speaker)
          .then((_) {
        _beforeNextPaint(speechElement.remove);
        onReply.cancel();
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
