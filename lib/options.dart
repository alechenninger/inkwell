// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.options;

import 'package:august/august.dart';

class OptionsModule {
  final StreamController _ctrl = new StreamController.broadcast(sync: true);

  Options get scriptOptions => new Options(this);

  OptionsInterface get interfaceOptions => new OptionsInterface(this);

  parseCommand(String name, Map args) {
    switch (name) {
      case "use":
      default:
        throw new ArgumentError.value(name, "name", "Unknown command");
    }
  }

  final List<Option> _options = [];

  Option _newOption(String text) {
    return new Option(text)
      ..onUse.listen((u) => _ctrl.add(new UseOptionEvent(u.option)))
      ..availability.onEnter.listen((e) {
        _options.add(e.owner);
        _ctrl.add(new AddOptionEvent(e.owner));
      })
      ..availability.onExit.listen((e) {
        _options.remove(e.owner);
        _ctrl.add(new RemoveOptionEvent(e.owner));
      });
  }
}

class Options {
  final OptionsModule _module;

  Options(this._module);

  Option newOption(String text) => _module._newOption(text);
}

class UiOption {

}

class OptionsInterface implements Interface {
  final OptionsModule _options;

  OptionsInterface(this._options);

  void use(UiOption option) {

  }

  List<UiOption> get available => null;

  Stream<UiOption> get additions => null;

  Stream<UiOption> get removals => null;

  Stream<UiOption> get uses => null;
}

class OptionsInterfaceHandler implements InterfaceHandler {
  final Options _options;

  OptionsInterfaceHandler(this._options);

  void handle(String action, Map args) {
    // TODO: Reimplement
  }
}

class Option {
  final String text;

  final int allowedUseCount;

  Observed<int> get useCount => _useCount;

  bool get isAvailable => _available.observed.value;

  /// A scope that is entered whenever this option is available.
  Scope<StateChangeEvent<bool>> get availability => _available.asScope;

  Stream<UseOptionEvent> get onUse => _uses.stream;

  final SettableScope _hasUses = new SettableScope.notEntered();
  final StreamController _uses = new StreamController.broadcast(sync: true);
  Observable<int> _useCount;
  ScopeAsValue _available;

  Option(this.text, {this.allowedUseCount: 1}) {
    _useCount = new Observable.ofImmutable(0, owner: this);
    _available = new ScopeAsValue(owner: this);

    if (allowedUseCount < 0) {
      throw new ArgumentError.value(allowedUseCount, "allowedUseCount",
          "Allowed use count must be non-negative.");
    }

    if (allowedUseCount > 0) {
      _hasUses.enter(null);
    }
  }

  /// Set a scope which contributes to determining this options availability.
  /// An option's availability is always governed by its [useCount] and
  /// [allowedUseCount] in addition to the provided scope.
  ///
  /// See [isAvailable] and [availability].
  void available(Scope scope) {
    _available.within(new AndScope(scope, _hasUses));
  }

  Future<UseOptionEvent> use() {
    if (_available.observed.nextValue == false) {
      return new Future.error(new OptionNotAvailableException(this));
    }

    _useCount.set((c) => c + 1);

    if(_useCount.nextValue == allowedUseCount) {
      _hasUses.exit(null);
    }

    return new Future(() {
      var event = new UseOptionEvent(this);
      _uses.add(event);
      return event;
    });
  }
}

class AddOptionEvent {
  final Option option;

  AddOptionEvent(this.option);
}

class RemoveOptionEvent {
  final Option option;

  RemoveOptionEvent(this.option);
}

class UseOptionEvent {
  final Option option;

  UseOptionEvent(this.option);
}

class OptionNotAvailableException implements Exception {
  final Option option;

  OptionNotAvailableException(this.option);
}
