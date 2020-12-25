import 'package:august/august.dart';
import 'package:august/dialog.dart';
import 'package:august/options.dart';
import 'package:pedantic/pedantic.dart';
import 'package:test/test.dart';

void main() {
  Palette Function() clearPalette;
  List log;
  var storyNum = 0;
  Completer storyDone;

  setUp(() {
    clearPalette = () {
      var dialog = Dialog();
      var options = Options();
      return Palette([dialog, options]);
    };
    log = [];
    storyNum = 0;
    storyDone = Completer()..complete();
  });

  Future<Story> logEvents(Story story) async {
    await storyDone.future;
    storyDone = Completer();
    var _storyNum = storyNum++;
    log.add('started $_storyNum');
    unawaited(story.events
        .forEach((e) => log.add(e))
        .then((_) {
          log.add('stopped $_storyNum');
          storyDone.complete();
        }));
    return story;
  }

  group('narrator', () {
    Narrator n;

    tearDown(() {
      return n?.stop()?.timeout(Duration(seconds: 1));
    });

    test('emits events from story', () async {
      void script(Palette p) {
        p<Dialog>().narrate('test');
      }

      n = Narrator(script, InMemoryArchive(), Stopwatch(), clearPalette);

      await logEvents(await n.start());
      await eventLoop;

      expect(log, contains(SpeechAvailable(null, 'test', null)));
    });

    test('performs actions', () async {
      void script(Palette p) {
        p<Dialog>().narrate('test');
        p<Options>().oneTime('test it').onUse.listen((_) {
          p<Dialog>().add('tested');
        });
      }

      n = Narrator(script, InMemoryArchive(), Stopwatch(), clearPalette);
      var story = await logEvents(await n.start());
      await eventLoop;
      story.attempt(UseOption('test it'));
      await eventLoop;
      expect(log, contains(SpeechAvailable(null, 'tested', null)));
    });

    test('restarts stories', () async {
      void script(Palette p) {
        p<Dialog>().narrate('test');
        p<Options>().oneTime('test it').onUse.listen((_) {
          p<Dialog>().add('tested');
        });
      }

      n = Narrator(script, InMemoryArchive(), Stopwatch(), clearPalette);
      var story = await logEvents(await n.start());
      await eventLoop;
      story.attempt(UseOption('test it'));
      await eventLoop;
      await n.stop();
      story = await logEvents(await n.start());
      await eventLoop;
      expect(
          log.sublist(log.indexOf('stopped 0')),
          equals([
            'stopped 0',
            'started 1',
            SpeechAvailable(null, 'test', null),
            OptionAvailable('test it'),
          ]));
    });
  }, timeout: Timeout(Duration(seconds: 1)));
}

Future get eventLoop => Future(() {});

