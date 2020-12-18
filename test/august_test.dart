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

    void story() {
      dialog.narrate('test');
    }

    test('emits events to UI', () async {
      play(story, NoPersistence(), testUi, {dialog, options});
      await delay(seconds: 1);
      expect(testUi.eventLog, contains(SpeechAvailable(null, 'test', null)));
    });
  });
}

class TestUi extends UserInterface {
  final _actions = StreamController<Action<StoryModule<Event>>>();
  final eventLog = [];

  void perform(Action<StoryModule<Event>> action) {
    _actions.add(action);
  }

  @override
  Stream<Action<StoryModule<Event>>> get actions => _actions.stream;

  @override
  void play(Stream<Event> events) {
    events.listen((e) => eventLog.add(e));
  }

}
