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
import 'package:pedantic/pedantic.dart' show unawaited;

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
  final _continue = ButtonElement()
    ..id = 'continue'
    ..classes.add('material-icons')
    ..text = 'playlist_play';

  final _domQueue = Queue<Function>();
  Stream<Action> get actions => _actions.stream.where((event) => !_paused);

  final _interrupts = StreamController<Interrupt>();

  // TODO: bundle this related state up?

  Stream<Event> _events;
  var _actions = StreamController<Action>();
  bool _paused = false;
  Completer _stopped;

  SimpleHtmlUi(Element _container) {
    _container.children.addAll(
        [_start, _restart, _continue, _optionsContainer, _dialogContainer]);

    _start.onClick.listen((event) {
      // TODO: manage state change based on events?
      if (_events == null) {
        _interrupts.add(StartStory());
        _start.text = 'pause';
      } else if (!_paused) {
        _interrupts.add(PauseStory());
        _paused = true;
        _start.text = 'play_arrow';
      } else {
        _interrupts.add(ResumeStory());
        _paused = false;
        _start.text = 'pause';
      }
    });

    _restart.onClick.listen((event) {
      _interrupts.add(StartStory());
    });

    _continue.onClick.listen((event) {
      _interrupts.add(ContinueStory());
    });
  }

  @override
  Stream<Interrupt> get interrupts => _interrupts.stream;

  @override
  void notice(Stream<Notice> notices) {
    notices.listen((n) {
      print('notice: ${n.message}');
    });
  }

  @override
  void play(Stream<Event> events) {
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
            ..innerHtml = speech.target == null
                ? speech.speaker
                : '${speech.speaker} to...');
    }

    UListElement repliesElement;

    var onReply = _events
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

      _events
          .whereType<ReplyUnavailable>()
          .firstWhere((r) => r.reply == reply.key)
          .then(
              // TODO consider alternate behavior vs used and removed vs just removed
              // vs unavailable due to exclusive reply use
              (_) => _beforeNextPaint(replyElement.remove),
              onError: (e) {});
    });

    _events
        .whereType<SpeechUnavailable>()
        .firstWhere((s) => s.key == speech.key)
        .then((_) {
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

class HtmlUi2 {
  final Narrator _narrator;

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
  final _continue = ButtonElement()
    ..id = 'continue'
    ..classes.add('material-icons')
    ..text = 'playlist_play';

  final _domQueue = Queue<Function>();
  StreamController<Event> _events;
  Completer _cleanedUp = Completer.sync()..complete();
  Stream<Event> get _eventsStream => _events?.stream;

  Story _story;

  HtmlUi2(this._narrator, Element _container) {
    _container.children.addAll(
        [_start, _restart, _continue, _optionsContainer, _dialogContainer]);

    _start.onClick.listen((event) async {
      // TODO: transition states while waiting for futures
      if (_story == null) {
        _story = await _narrator.start();
        _play(_story.events);
      } else if (!_story.isPaused) {
        _story.pause(); // TODO: should return future?
        _start.text = 'play_arrow';
      } else {
        _story.resume();
        _start.text = 'pause';
      }
    });

    _restart.onClick.listen((event) async {
      _story = await _narrator.start();
      _play(_story.events);
    });

    _continue.onClick.listen((event) async {
      // TODO: pick from saves
      _story = await _narrator.continueFrom(_narrator.saves().first);
      _play(_story.events);
    });
  }

  void _play(Stream<Event> events) async {
    // if (_story != null) {
    //   throw StateError('Cannot listen to multiple event streams '
    //       'simultaneously. Ensure prior event stream is closed first.');
    // }

    // _stopped = Completer.sync();
    await _events?.close();
    await _cleanedUp.future;

    _events = StreamController<Event>.broadcast(sync: true);
    _cleanedUp = Completer();
    _start.text = 'pause';

    _eventsStream.doOnDone(() {
      _beforeNextPaint(() {
        _optionsContainer.children.clear();
        _dialogContainer.children.clear();
        _cleanedUp.complete();
      });
      _start.text = 'play_arrow';
    }).handleError((Object err) {
      print(err);
    });

    _eventsStream.whereType<SpeechAvailable>().listen(_onSpeechAvailable);
    _eventsStream.whereType<OptionAvailable>().listen(_onOptionAvailable);

    events.listen((event) {
      _events.add(event);
    }, onError: (e) => _events.addError(e), onDone: () => _events.close());
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
            ..innerHtml = speech.target == null
                ? speech.speaker
                : '${speech.speaker} to...');
    }

    UListElement repliesElement;

    var onReply = _eventsStream
        .whereType<ReplyAvailable>()
        .where((r) => r.speech == speech.key)
        .listen((reply) {
      var replyElement = LIElement()
        ..children.add(SpanElement()
          ..classes.addAll(['reply', 'reply-available'])
          ..innerHtml = reply.markup
          ..onClick.listen((_) => _addAction(UseReply(reply.key))));

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

      _eventsStream
          .whereType<ReplyUnavailable>()
          .firstWhere((r) => r.reply == reply.key)
          .then(
              // TODO consider alternate behavior vs used and removed vs just removed
              // vs unavailable due to exclusive reply use
              (_) => _beforeNextPaint(replyElement.remove),
              onError: (e) {});
    });

    _eventsStream
        .whereType<SpeechUnavailable>()
        .firstWhere((s) => s.key == speech.key)
        .then((_) {
      _beforeNextPaint(speechElement.remove);
      onReply.cancel();
    }, onError: (e) {});
  }

  void _onOptionAvailable(OptionAvailable option) {
    var optionElement = LIElement()
      ..children.add(SpanElement()
        ..classes.add('option')
        ..innerHtml = option.option
        ..onClick.listen((_) => _addAction(UseOption(option.option))));

    _beforeNextPaint(() {
      _optionsContainer.children.add(optionElement);
    });

    _eventsStream
        .whereType<OptionUnavailable>()
        .firstWhere((o) => o.option == option.option)
        .then((_) => _beforeNextPaint(optionElement.remove), onError: (e) {});
  }

  void _addAction(Action action) {
    // TODO: check story in progress
    _story.attempt(action);
  }
}
