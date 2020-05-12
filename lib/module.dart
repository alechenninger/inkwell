import 'package:built_value/serializer.dart';

import 'src/events.dart';

abstract class Module extends Emitter {
  Serializers get serializers;
}
