part of august.modules;

class OptionsModule implements ModuleDefinition, HasInterface {
  Options create(Once once, Every every, Emit emit, Map modules) {
    return new Options(every, emit);
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
  final Emit _emit;
  final Every _every;

  Options(this._every, this._emit);

  bool add(String option) {
    if (_opts.add(option)) {
      _emit(new AddOptionEvent(option));
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
      _emit(new RemoveOptionEvent(option));
      return true;
    }
    return false;
  }

  /// Emits an [Event] with the [option] as its alias and removes it from the
  /// list of available options. Other mutually exclusive options are removed as
  /// well.
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

    _emit(new UseOptionEvent(option));
  }

  Set<String> get available => new Set.from(_opts);

  Stream<AddOptionEvent> get additions => _every((e) => e is AddOptionEvent);

  Stream<RemoveOptionEvent> get removals =>
      _every((e) => e is RemoveOptionEvent);

  Stream<UseOptionEvent> get uses => _every((e) => e is UseOptionEvent);
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

  Stream<String> get uses => _options.uses.map((e) => e.option);
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

class AddOptionEvent implements Event {
  // I think maybe alias should not be a thing every event has to have
  final String alias;
  final String option;

  AddOptionEvent(String option)
      : this.option = option,
        this.alias = "Add option $option";
}

class RemoveOptionEvent implements Event {
  final String alias;
  final String option;

  RemoveOptionEvent(String option)
      : this.option = option,
        this.alias = "Remove option $option";
}

class UseOptionEvent implements Event {
  final String alias;
  final String option;

  UseOptionEvent(String option)
      : this.option = option,
        this.alias = option;
}
