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
      options.oneTime('test it').onUse.listen((event) {
        dialog.add('tested');
      });
    }

    test('emits events to UI', () async {
      play(story, NoPersistence(), testUi, {dialog, options});
      testUi.perform(UseOption('test it'));
      await Future(() => {});
      expect(testUi.eventLog, contains(SpeechAvailable(null, 'tested', null)));
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

  @override
  // TODO: implement metaActions
  Stream<MetaAction> get metaActions => Stream.empty();

}
