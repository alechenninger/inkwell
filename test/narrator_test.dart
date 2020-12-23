import 'dart:math';

import 'package:august/august.dart';
import 'package:august/dialog.dart';
import 'package:august/options.dart';
import 'package:test/test.dart';
import 'package:rxdart/rxdart.dart';

void main() {
  Palette Function() clearPalette;
  TestUi testUi;

  setUp(() {
    clearPalette = () {
      var dialog = Dialog();
      var options = Options();
      return Palette([dialog, options]);
    };
    testUi = TestUi();
  });

  group('narrator', () {
    Narrator n;

    tearDown(() {
      return n?.stop()?.timeout(Duration(seconds: 1));
    });

    test('emits events to UI', () async {
      void script(Palette p) {
        p<Dialog>().narrate('test');
      }

      n = Narrator(script, InMemoryArchive(), Stopwatch(), Random(),
          clearPalette, testUi);

      await n.start();
      await eventLoop;

      expect(testUi.eventLog, contains(SpeechAvailable(null, 'test', null)));
    });

    test('performs actions from UI', () async {
      void script(Palette p) {
        p<Dialog>().narrate('test');
        p<Options>().oneTime('test it').onUse.listen((_) {
          p<Dialog>().add('tested');
        });
      }

      n = Narrator(script, InMemoryArchive(), Stopwatch(), Random(),
          clearPalette, testUi);
      await n.start();
      await eventLoop;
      testUi.attempt(UseOption('test it'));
      await eventLoop;
      expect(testUi.eventLog, contains(SpeechAvailable(null, 'tested', null)));
    });

    test('restarts stories', () async {
      void script(Palette p) {
        p<Dialog>().narrate('test');
        p<Options>().oneTime('test it').onUse.listen((_) {
          p<Dialog>().add('tested');
        });
      }

      n = Narrator(script, InMemoryArchive(), Stopwatch(), Random(),
          clearPalette, testUi);
      await n.start();
      await eventLoop;
      testUi.attempt(UseOption('test it'));
      await eventLoop;
      await n.stop();
      await n.start();
      await eventLoop;
      expect(
          testUi.eventLog.sublist(testUi.eventLog.indexOf('stopped 0')),
          equals([
            'stopped 0',
            'started 1',
            SpeechAvailable(null, 'test', null),
            OptionAvailable('test it'),
          ]));
    });
  }, timeout: Timeout(Duration(seconds: 1)));

  group('story', () {
    test('closes', () async {
      void script(Palette p) {
        p<Dialog>().narrate('test');
      }

      var palette = clearPalette();
      testUi.play(palette.events);
      var s = Story(
          'id', script, palette, Stopwatch(), testUi.actions, Version('test'));
      await eventLoop;
      expect(s.close(), completes);
    });
  }, timeout: Timeout(Duration(seconds: 1)));
}

Future get eventLoop => Future(() {});

class TestUi extends UserInterface {
  StreamController<Action<Ink<Event>>> _actions;
  final eventLog = [];
  int _plays = 0;
  Completer _stopped;

  void attempt(Action<Ink<Event>> action) {
    if (_actions == null) throw StateError('no story in progress');
    _actions.add(action);
  }

  @override
  Stream<Action<Ink<Event>>> get actions {
    if (_actions == null) throw StateError('no story in progress');
    return _actions.stream;
  }

  @override
  void play(Stream<Event> events) {
    if (_actions != null) throw StateError('story in progress');
    _actions = StreamController<Action<Ink<Event>>>();
    _stopped = Completer.sync();
    eventLog.add('started $_plays');
    events.listen((e) => eventLog.add(e), onDone: () async {
      await _actions.close();
      eventLog.add('stopped ${_plays++}');
      _actions = null;
      _stopped.complete();
    });
  }

  @override
  Stream<Interrupt> get interrupts => Stream.empty();

  @override
  Future get stopped => _stopped?.future ?? Future.sync(() {});
}
