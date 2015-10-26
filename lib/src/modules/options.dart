part of august.modules;

class OptionsModule implements ModuleDefinition, HasInterface {
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
  final Set _opts = new Set();
  final List<Set> _exclusives = new List();
  final Run _run;

  Options(this._run);

  bool add(String option) {
    if (_opts.add(option)) {
      _run.emit(new AddOptionEvent(option));
      return true;
    }
    return false;
  }

  /// Adds all of the options, and binds them together such that the use of any
  /// of them, removes the rest. That is, they are mutually exclusive options.
  ///
  /// The same option may be in multiple sets of exclusive options. The option
  /// will still be available once, and therefore it's use will remove all sets
  /// of mutually exclusive options.
  void addExclusive(Iterable<String> options) {
    var asSet = options.toSet();
    asSet.forEach(add);
    _exclusives.add(asSet);
  }

  bool remove(String option) {
    if (_opts.remove(option)) {
      _run.emit(new RemoveOptionEvent(option));
      return true;
    }
    return false;
  }

  bool removeIn(Iterable<String> options) {
    bool removed = false;
    options.forEach((o) {
      removed = remove(o) || removed;
    });
    return removed;
  }

  /// Emits an [NamedEvent] with the [option] as its name and removes it from
  /// the list of available options. Other mutually exclusive options are
  /// removed as well.
  ///
  /// Throws an [ArgumentError] if the `option` is not available.
  void use(String option) {
    if (!_opts.remove(option)) {
      throw new ArgumentError.value(
          option, "option", "Option not available to be used.");
    }

    _exclusives
        .where((s) => s.contains(option))
        .forEach((s) => s.forEach(remove));
    _exclusives.removeWhere((s) => s.contains(option));

    _run.emit(new UseOptionEvent(option));
  }

  Set<String> get available => new Set.from(_opts);

  Stream<AddOptionEvent> get additions =>
      _run.every((e) => e is AddOptionEvent);

  Stream<RemoveOptionEvent> get removals =>
      _run.every((e) => e is RemoveOptionEvent);

  Stream<UseOptionEvent> get uses => _run.every((e) => e is UseOptionEvent);
}

class OptionsInterface {
  final Options _options;
  final InterfaceEmit _emit;

  OptionsInterface(this._options, this._emit);

  void use(String option) {
    _emit("use", {"option": option});
  }

  Set<String> get available => _options.available;

  Stream<String> get additions => _options.additions.map((e) => e.option);

  Stream<String> get removals => _options.removals.map((e) => e.option);

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
  final String option;

  AddOptionEvent(this.option);
}

class RemoveOptionEvent {
  final String option;

  RemoveOptionEvent(this.option);
}

class UseOptionEvent implements NamedEvent {
  final String name;

  UseOptionEvent(this.name);
}
