// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:august/august.dart';

class Options {
  final _availableOptCtrl = new StreamController<Option>.broadcast(sync: true);
  final _options = <Option>[];

  Stream<Option> get onOptionAvailable => _availableOptCtrl.stream;

  Option newOption(String text, {Scope available}) {
    var option = new Option(text)
      ..availability.onEnter.listen((e) {
        var option = e.owner as Option;
        _options.add(option);
        _availableOptCtrl.add(option);
      })
      ..availability.onExit.listen((e) {
        var option = e.owner as Option;
        _options.remove(option);
      });

    if (available != null) {
      option.available(available);
    }

    if (option.isAvailable) {
      _options.add(option);
      _availableOptCtrl.add(option);
    }

    return option;
  }
}

class Option {
  final String text;

  final int allowedUseCount;

  /// Ticks as soon as [use] is called should the use be permitted.
  // TODO: Should be observed as immediate state changes are unreliable (lossy).
  // A consumer may like to know what the use count was before other listeners
  // fired in this event loop.
  int get useCount => _useCount;
  int _useCount = 0;

  ScopeAsValue _available;

  /// As of the start of this event loop. If the option is used, this will be
  /// reflected on the next event loop.
  bool get isAvailable => _available.observed.value;

  bool get willBeAvailable => _available.observed.nextValue;

  /// A scope that is entered whenever this option is available.
  Scope<StateChangeEvent<bool>> get availability => _available.asScope;

  // TODO: Consider simply Stream<Option>
  Stream<UseOptionEvent> get onUse => _uses.stream;

  final _hasUses = new SettableScope.notEntered();
  final _uses = new StreamController<UseOptionEvent>.broadcast(sync: true);

  Option(this.text, {this.allowedUseCount: 1}) {
    if (allowedUseCount < 0) {
      throw new ArgumentError.value(allowedUseCount, "allowedUseCount",
          "Allowed use count must be non-negative.");
    }

    _available = new ScopeAsValue(owner: this)..within(_hasUses);

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

  /// Schedules option to be used at the end of the current event queue.
  ///
  /// The return future completes with success when the option is used and all
  /// listeners receive it. It completes with an error if the option is not
  /// available to be used.
  Future<UseOptionEvent> use() {
    if (_available.observed.nextValue == false) {
      return new Future.error(new OptionNotAvailableException(this));
    }

    _useCount += 1;

    if (_useCount == allowedUseCount) {
      _hasUses.exit(null);
    }

    return new Future(() {
      var event = new UseOptionEvent(this);
      _uses.add(event);
      return event;
    });
  }

  String toString() => "Option{"
      "text='$text',"
      "allowedUseCount=$allowedUseCount,"
      "useCount=$_useCount"
      "}";
}

class OptionsUi {
  final Options _options;
  final Sink<Interaction> _interactions;

  OptionsUi(this._options, this._interactions);

  Stream<UiOption> get onOptionAvailable =>
      _options.onOptionAvailable.map((o) => new UiOption(_interactions, o));
}

class UiOption {
  final Option _option;
  final Sink<Interaction> _interactions;

  String get text => _option.text;

  UiOption(this._interactions, this._option);

  void use() {
    _interactions.add(new _UseOption(_option));
  }

  Stream<UiOption> get onUse => _option.onUse.map((e) => this);

  Stream<UiOption> get onUnavailable =>
      _option.availability.onExit.map((e) => this);
}

class _UseOption implements Interaction {
  final String moduleName = "$Options";
  final String name = "$_UseOption";

  Map<String, dynamic> _params;
  Map<String, dynamic> get parameters => _params;

  _UseOption(Option option) {
    _params = {"text": option.text};
  }

  static void run(Map<String, dynamic> parameters, Options options) {
    if (!parameters.containsKey('text')) {
      throw new ArgumentError.value(
          parameters,
          'parameters',
          'Expected json to contain '
          '"text" field.');
    }

    var text = parameters['text'];
    var found =
        options._options.firstWhere((o) => o.text == text, orElse: null);

    if (found == null) {
      throw new StateError('No option found from text "$text".');
    }

    found.use();
  }
}

class OptionsInteractor implements Interactor {
  final Options _options;

  OptionsInteractor(this._options);

  void run(String interaction, Map<String, dynamic> parameters) {
    if (interaction == "$_UseOption") {
      _UseOption.run(parameters, _options);
    } else {
      throw new UnsupportedError("Unsupported interaction: $interaction");
    }
  }

  @override
  String get moduleName => "$Options";
}

class UseOptionEvent {
  final Option option;

  UseOptionEvent(this.option);
}

// Not sure if this should be error or exception
// Depends on context, so probably exception
class OptionNotAvailableException implements Exception {
  final Option option;

  OptionNotAvailableException(this.option);
}
