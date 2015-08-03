part of august.modules;

class OptionsModule implements ModuleDefinition, HasInterface {
  Options create(Once once, Every every, Emit emit, Map modules) {
    return new Options(emit);
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

  Options(this._emit);

  bool add(String option) => _opts.add(option);

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

  bool remove(String option) => _opts.remove(option);

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

    _exclusives.where((s) => s.contains(option)).forEach((s) {
      s.forEach((o) {
        _opts.remove(o);
      });
      _exclusives.remove(s);
    });

    _emit(new Event(option));
  }

  Set<String> get available => new Set.from(_opts);
}

class OptionsInterface {
  final Options _options;
  final InterfaceEmit _emit;

  OptionsInterface(this._options, this._emit);

  void use(String option) {
    // UserEmit created per module so scope is restricted by default
    _emit("use", {"option": option});
  }

  Set<String> get available => _options.available;
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
