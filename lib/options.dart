// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.options;

import 'package:august/august.dart';
import 'package:quiver/core.dart' as quiver show hash2;

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
  /// `Option` name to `Option` instance.
  final Map<String, Option> _opts = <String, Option>{};
  final List<Set<Option>> _exclusives = <Set<Option>>[];
  final Run _run;

  Options(this._run);

  Future<AddOptionEvent> add(String text,
      {String named, Duration delay: Duration.ZERO}) {
    return _addOption(new Option(text, named: named), delay: delay);
  }

  /// Adds all of the options, and binds them together such that the use of any
  /// of them, removes the rest. That is, they are mutually exclusive options.
  ///
  /// The same option may be in multiple sets of exclusive options. The option
  /// will still be available once, and therefore it's use will remove all sets
  /// of mutually exclusive options.
  ///
  /// The [Iterable] may include [Option]s or [String]s. An `Option` created
  /// from a `String` uses that `String` for both its text and name.
  void addExclusive(Iterable<dynamic> options,
      {Duration delay: Duration.ZERO}) {
    Set<Option> exclusiveSet =
        options.map((o) => o is Option ? o : new Option(o)).toSet();
    exclusiveSet.forEach(_addOption);
    _exclusives.add(exclusiveSet);
  }

  bool remove(String option) {
    var removed = _opts.remove(option);
    if (removed == null) return false;

    _run.emit(new RemoveOptionEvent(removed));
    return true;
  }

  bool removeIn(Iterable<String> options) {
    bool removed = false;
    for (var option in options) {
      removed = remove(option) || removed;
    }
    return removed;
  }

  /// Emits an [NamedEvent] with the [option] as its name and removes it from
  /// the list of available options. Other mutually exclusive options are
  /// removed as well.
  ///
  /// Throws an [ArgumentError] if the `option` is not available.
  void use(String option) {
    var used = _opts.remove(option);

    if (used == null) {
      throw new ArgumentError.value(
          option, "option", "Option not available to be used.");
    }

    for (var i = 0; i < _exclusives.length;) {
      var exclusiveSet = _exclusives[i];
      if (exclusiveSet.any((o) => o.name == option)) {
        for (var exclusiveOption in exclusiveSet) {
          remove(exclusiveOption.name);
        }

        _exclusives.removeAt(i);
      } else {
        i++;
      }
    }

    _run.emit(new UseOptionEvent(used));
  }

  Set<String> get available => new Set.from(_opts.keys);

  Future<UseOptionEvent> once(String option) =>
      uses.firstWhere((u) => u.option.name == option);

  Stream<AddOptionEvent> get additions =>
      _run.every((e) => e is AddOptionEvent);

  Stream<RemoveOptionEvent> get removals =>
      _run.every((e) => e is RemoveOptionEvent);

  Stream<UseOptionEvent> get uses => _run.every((e) => e is UseOptionEvent);

  Future<AddOptionEvent> _addOption(Option option,
      {Duration delay: Duration.ZERO}) {
    if (delay.inMicroseconds == 0) {
      if (!_opts.containsKey(option.name)) {
        _opts[option.name] = option;

        return _run.emit(new AddOptionEvent(option));
        // onEnter: option.enable() or options.enable(option);
        // onExit: option.disable(); or options.disable(option);
      }

      return new Future.value(null);
    }

    return new Future.delayed(delay, () {
      if (!_opts.containsKey(option.name)) {
        _opts[option.name] = option;
        return _run.emit(new AddOptionEvent(option));
      }
      return null;
    });
  }
}

class OptionsInterface implements Interface {
  final Options _options;
  final InterfaceEmit _emit;

  OptionsInterface(this._options, this._emit);

  void use(String option) {
    _emit("use", {"option": option});
  }

  Set<String> get available => _options.available;

  Stream<Option> get additions => _options.additions.map((e) => e.option);

  Stream<Option> get removals => _options.removals.map((e) => e.option);

  Stream<Option> get uses => _options.uses.map((e) => e.option);
}

class OptionsInterfaceHandler implements InterfaceHandler {
  final Options _options;

  OptionsInterfaceHandler(this._options);

  void handle(String action, Map args) {
    switch (action) {
      case "use":
        _options.use(args["option"]);
    }
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
  Scoped _available;

  Option(this.text, this._run, {this.allowedUseCount: 1}) {
    _available = new Scoped(onEnter: _add, onExit: _remove);
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

  // TODO: How does use affect availability?
  // 1. It does not at all. Availability may be set to include `untilUsed(n)`.
  // 2. Once used n times, sets availability = never.

  bool get isAvailable => _available.isInScope;

  /// A scope that is entered whenever this option is available.
  Scope get availability => _available.scope;

  void _add(_) {
    _run.emit(new AddOptionEvent(this));
  }

  void _remove(_) {
    _run.emit(new RemoveOptionEvent(this));
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
