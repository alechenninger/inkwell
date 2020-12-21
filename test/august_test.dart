import 'package:august/august.dart';
import 'package:august/dialog.dart';
import 'package:august/options.dart';
import 'package:test/test.dart';

void main() {
  group('august', () {
    Dialog dialog;
    Options options;
    TestUi testUi;

    setUp(() {
      dialog = Dialog();
      options = Options();
      testUi = TestUi();
    });

    test('emits events to UI', () async {
      void story() {
        dialog.narrate('test');
        options.oneTime('test it').onUse.listen((event) {
          dialog.add('tested');
        });
      }

      play(story, NoPersistence(), testUi, {dialog, options});
      await Future(() => {});
      expect(testUi.eventLog, contains(SpeechAvailable(null, 'tested', null)));
    });

    test('emits events to UI', () async {
      void story() {
        dialog.narrate('test');
        options.oneTime('test it').onUse.listen((event) {
          dialog.add('tested');
        });
      }

      play(story, NoPersistence(), testUi, {dialog, options});
      testUi.perform(UseOption('test it'));
      await Future(() => {});
      expect(testUi.eventLog, contains(SpeechAvailable(null, 'tested', null)));
    });
  });
}

class TestUi extends UserInterface {
  final _actions = StreamController<Action<Ink<Event>>>();
  final eventLog = [];

  void perform(Action<Ink<Event>> action) {
    _actions.add(action);
  }

  @override
  Stream<Action<Ink<Event>>> get actions => _actions.stream;

  @override
  Future play(Stream<Event> events) {
    events.listen((e) => eventLog.add(e));
  }

  @override
  Stream<Interrupt> get interrupts => Stream.empty();

  @override
  // TODO: implement stopped
  Future get stopped => throw UnimplementedError();

}
