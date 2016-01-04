// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.options;

import 'package:august/august.dart';

class OptionsDefinition implements ModuleDefinition, InterfaceModuleDefinition {
  final name = 'Options';

  Options createModule(Run run, Map modules) {
    return new Options(run);
  }

  OptionsInterface createInterface(Options options, InterfaceEmit emit) {
    return new OptionsInterface(options, emit);
  }

  OptionsInterfaceHandler createInterfaceHandler(Options options) {
    return new OptionsInterfaceHandler(options);
  }
}

class Options {
  final List<Option> _available = <Option>[];
  final Run _run;

  Options(this._run) {
    additions.listen((e) => _available.add(e.option));
    removals.listen((e) => _available.remove(e.option));
  }

  List<Option> get available =>
      // Check for availability explicitly because events may not have been
      // received yet.
      new List.unmodifiable(_available.where((Option o) => o.isAvailable));

  Stream<AddOptionEvent> get additions =>
      _run.every((e) => e is AddOptionEvent);

  Stream<RemoveOptionEvent> get removals =>
      _run.every((e) => e is RemoveOptionEvent);

  Stream<UseOptionEvent> get uses => _run.every((e) => e is UseOptionEvent);
}

class OptionsInterface implements Interface {
  final Options _options;
  final InterfaceEmit _emit;

  OptionsInterface(this._options, this._emit);

  void use(String option) {
    _emit("use", {"option": option});
  }

  // TODO: UI shouldn't access native Options directly
  // must keep track of UI events, persist them
  List<Option> get available => _options.available;

  Stream<Option> get additions => _options.additions.map((e) => e.option);

  Stream<Option> get removals => _options.removals.map((e) => e.option);

  Stream<Option> get uses => _options.uses.map((e) => e.option);
}

class OptionsInterfaceHandler implements InterfaceHandler {
  final Options _options;

  OptionsInterfaceHandler(this._options);

  void handle(String action, Map args) {
    // TODO: Reimplement
  }
}

class Option {
  // TODO: Maybe allow mutable text too?
  final String text;
  final Run _run;
  final SettableScope _hasUses = new SettableScope.notEntered();

  final int allowedUseCount; // TODO: Allow mutate

  int _useCount = 0;
  int get useCount => _useCount;

  final ScopeAsValue _available = new ScopeAsValue();

  Option(this.text, this._run, {this.allowedUseCount: 1}) {
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

  bool get isAvailable => _available.isInScope;

  /// A scope that is entered whenever this option is available.
  Scope get availability => _available.asScope;

  Future<UseOptionEvent> use() {
    return _run.emit(() {
      if (!isAvailable) {
        throw new StateError("Option is not available to be used.");
      }

      _useCount += 1;
      var event = new UseOptionEvent(this);

      if (_useCount == allowedUseCount) {
        _hasUses.exit(event);
      }

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
