import 'dart:io';
import 'dart:isolate';

main(){
  ReceivePort receivePort = new ReceivePort();
  Isolate.spawn(isolateEntryPoint, receivePort.sendPort).then((isolate) async {
    print("pausing isolate");
    var resume = isolate.pause(isolate.pauseCapability);
    Future.delayed(Duration(seconds: 5), () {
      print("resuming isolate");
      isolate.resume(resume);
      print("after resumed");
    });
  });
}

void isolateEntryPoint(SendPort sendPort) async {
  var stopwatch = Stopwatch()..start();
  while(true) {
    print("isolate is running ${stopwatch.elapsed}");
    await Future.delayed(Duration(seconds: 10), () { print("future ${stopwatch.elapsed}"); });;
    print("after future ${stopwatch.elapsed}");
  }
}
