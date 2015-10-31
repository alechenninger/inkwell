part of august.modules;

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

  bool add(String text, {String named}) {
    return _addOption(new Option(text, named: named));
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
  void addExclusive(Iterable<dynamic> options) {
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
      uses.firstWhere((u) => u.name == option);

  Stream<AddOptionEvent> get additions =>
      _run.every((e) => e is AddOptionEvent);

  Stream<RemoveOptionEvent> get removals =>
      _run.every((e) => e is RemoveOptionEvent);

  Stream<UseOptionEvent> get uses => _run.every((e) => e is UseOptionEvent);

  bool _addOption(Option option) {
    if (!_opts.containsKey(option.name)) {
      _opts[option.name] = option;
      _run.emit(new AddOptionEvent(option));
      return true;
    }
    return false;
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

  Stream<String> get removals => _options.removals.map((e) => e.name);

  Stream<String> get uses => _options.uses.map((e) => e.name);
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

class AddOptionEvent {
  final Option option;

  AddOptionEvent(this.option);
}

class RemoveOptionEvent {
  final String name;

  RemoveOptionEvent(Option option) : this.name = option.name;
}

class UseOptionEvent implements NamedEvent {
  final String name;

  UseOptionEvent(Option option) : this.name = option.name;
}

class Option {
  final String text;
  final String name;

  Option(String text, {String named})
      : this.text = text,
        this.name = (named == null) ? text : named;

  bool operator ==(other) =>
      other.runtimeType == Option && other.text == text && other.name == name;

  int get hashCode => quiver.hash2(text, name);
}
