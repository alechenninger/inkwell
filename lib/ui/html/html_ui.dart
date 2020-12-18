// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:collection';
import 'dart:html' hide Event;

import 'package:august/august.dart';
import 'package:august/dialog.dart';
import 'package:august/options.dart';
import 'package:august/ui.dart';
import 'package:rxdart/rxdart.dart';

/// Quick hacked together UI
class SimpleHtmlUi implements UserInterface {
  final _dialogContainer = DivElement()..classes.add('dialog');
  final _optionsContainer = UListElement()..classes.add('options');

  final _domQueue = Queue<Function>();

  final _actions = StreamController<Action>();
  Stream<Action> get actions => _actions.stream;

  SimpleHtmlUi(Element _container) {
    _container.children.addAll([_optionsContainer, _dialogContainer]);
  }

  void play(Stream<Event> events) {
    events.whereType<SpeechAvailable>().listen((speech) {
      var speechElement = DivElement()..classes.add('speech');

      _beforeNextPaint(() {
        _dialogContainer
          ..children.add(speechElement)
          ..scrollIntoView(ScrollAlignment.BOTTOM);
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
          .where((r) => r.speech == speech.key)
          .listen((reply) {
        var replyElement = LIElement()
          ..children.add(SpanElement()
            ..classes.addAll(['reply', 'reply-available'])
            ..innerHtml = reply.markup
            ..onClick.listen((_) => _actions.add(UseReply(reply.key))));

        if (repliesElement == null) {
          repliesElement = UListElement()..classes.add('replies');
          repliesElement.children.add(replyElement);
          _beforeNextPaint(() => speechElement
            ..children.add(repliesElement)
            ..scrollIntoView(ScrollAlignment.BOTTOM));
        } else {
          _beforeNextPaint(() => repliesElement
            ..children.add(replyElement)
            ..scrollIntoView(ScrollAlignment.BOTTOM));
        }

        events
            .whereType<ReplyUnavailable>()
            .firstWhere((r) => r.reply == reply.key)
            .then(
                // TODO consider alternate behavior vs used and removed vs just removed
                // vs unavailable due to exclusive reply use
                (_) => _beforeNextPaint(replyElement.remove));
      });

      events
          .whereType<SpeechUnavailable>()
          .firstWhere((s) => s.key == speech.key)
          .then((_) {
        _beforeNextPaint(speechElement.remove);
        onReply.cancel();
      });
    });

    events.whereType<OptionAvailable>().listen((option) {
      var optionElement = LIElement()
        ..children.add(SpanElement()
          ..classes.add('option')
          ..innerHtml = option.option
          ..onClick.listen((_) => _actions.add(UseOption(option.option))));

      _beforeNextPaint(() {
        _optionsContainer.children.add(optionElement);
      });

      events
          .whereType<OptionUnavailable>()
          .firstWhere((o) => o.option == option.option)
          .then((_) => _beforeNextPaint(optionElement.remove));
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
