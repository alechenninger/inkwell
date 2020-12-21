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
  final _start = ButtonElement()
    ..id = 'start'
    ..classes.add('material-icons')
    ..text = 'play_arrow';
  final _restart = ButtonElement()
    ..id = 'restart'
    ..classes.add('material-icons')
    ..text = 'replay';

  final _domQueue = Queue<Function>();
  Stream<Action> get actions => _actions.stream.where((event) => !_paused);

  final _metaActions = StreamController<MetaAction>();

  // TODO: bundle this related state up?

  Stream<Event> _events;
  var _actions = StreamController<Action>();
  bool _paused = false;
  Completer _stopped;

  SimpleHtmlUi(Element _container) {
    _container.children.addAll([_start, _restart, _optionsContainer, _dialogContainer]);

    _start.onClick.listen((event) {
      // TODO: manage state change based on events?
      if (_events == null) {
        _metaActions.add(StartStory());
        _start.text = 'pause';
      } else if (!_paused) {
        _metaActions.add(PauseStory());
        _paused = true;
        _start.text = 'play_arrow';
      } else {
        _metaActions.add(ResumeStory());
        _paused = false;
        _start.text = 'pause';
      }
    });

    _restart.onClick.listen((event) {
      _metaActions.add(StartStory());
    });
  }

  @override
  Stream<MetaAction> get metaActions => _metaActions.stream;

  @override
  Future play(Stream<Event> events) {
    if (_events != null) {
      throw StateError('Cannot listen to multiple event streams '
          'simultaneously. Ensure prior event stream is closed first.');
    }

    _paused = false;
    _start.text = 'pause';
    _stopped = Completer.sync();

    _events = events.doOnDone(() async {
      _beforeNextPaint(() {
        _optionsContainer.children.clear();
        _dialogContainer.children.clear();
      });
      await _actions.close();
      _events = null;
      _paused = false;
      _start.text = 'play_arrow';
      _actions = StreamController<Action>();
      _stopped.complete();
    }).handleError((Object err) {
      print(err);
    }).asBroadcastStream();

    _events.whereType<SpeechAvailable>().listen(_onSpeechAvailable);
    _events.whereType<OptionAvailable>().listen(_onOptionAvailable);

    return _stopped.future;
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

  void _onSpeechAvailable(SpeechAvailable speech) {
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
            ..innerHtml = speech.target == null ? speech.speaker : '${speech.speaker} to...');
    }

    UListElement repliesElement;

    var onReply =
        _events.whereType<ReplyAvailable>().where((r) => r.speech == speech.key).listen((reply) {
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

      _events.whereType<ReplyUnavailable>().firstWhere((r) => r.reply == reply.key).then(
          // TODO consider alternate behavior vs used and removed vs just removed
          // vs unavailable due to exclusive reply use
          (_) => _beforeNextPaint(replyElement.remove), onError: (e) {});
    });

    _events.whereType<SpeechUnavailable>().firstWhere((s) => s.key == speech.key).then((_) {
      _beforeNextPaint(speechElement.remove);
      onReply.cancel();
    }, onError: (e) {});
  }

  void _onOptionAvailable(OptionAvailable option) {
    var optionElement = LIElement()
      ..children.add(SpanElement()
        ..classes.add('option')
        ..innerHtml = option.option
        ..onClick.listen((_) => _actions.add(UseOption(option.option))));

    _beforeNextPaint(() {
      _optionsContainer.children.add(optionElement);
    });

    _events
        .whereType<OptionUnavailable>()
        .firstWhere((o) => o.option == option.option)
        .then((_) => _beforeNextPaint(optionElement.remove), onError: (e) {});
  }

  @override
  Future get stopped => _stopped?.future ?? Future.value();
}
