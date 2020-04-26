part of 'august.dart';

abstract class UiEvent {
  String get event;
  Map<String, dynamic> get parameters;
}
