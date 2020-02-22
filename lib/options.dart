// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:august/august.dart';

class Options {
  final _availableOptCtrl = StreamController<Option>();
  final _options = <Option>[];
  final GetScope _default;

  Options({GetScope defaultScope = getAlways}) : _default = defaultScope;

  Stream<Option> get onOptionAvailable => _availableOptCtrl.stream;

  // TODO: OptionGroup exclusive()
  // var a = exclusive.
  Option oneTime(String text, {Scope available}) {
    return limitedUse(text, available: available, uses: 1);
  }

  /// Creates a new limited use option that can be used while [available] and
  /// has remaining [uses].
  Option limitedUse(String text, {Scope available, int uses = 1}) {
    // TODO: Could just pass scope here and keep track of use state in closure
    var option = Option(text, uses: uses, available: available ?? _default());

    option
      ..availability.onEnter.listen((e) {
        _options.add(option);
        _availableOptCtrl.add(option);
      })
      ..availability.onExit.listen((e) {
        _options.remove(option);
      });

    if (option.isAvailable) {
      _options.add(option);
      _availableOptCtrl.add(option);
    }

    return option;
  }
}

class Option {
  final String text;

  final int uses;

  int get useCount => _useCount;
  int _useCount = 0;

  Scope _available;

  bool get isAvailable => _available.isEntered;

  /// A scope that is entered whenever this option is available.
  Scope get availability => _available;

  // TODO: Consider simply Stream<Option>
  Stream<UseOptionEvent> get onUse => _uses.stream;

  final SettableScope2 _hasUses;
  final _uses = Events<UseOptionEvent>();

  Option(this.text, {this.uses = 1, Scope available})
      : _hasUses =
            uses > 0 ? SettableScope2.entered() : SettableScope2.notEntered() {
    if (uses < 0) {
      throw ArgumentError.value(
          uses, 'allowedUseCount', 'Allowed use count must be non-negative.');
    }

    _available = available == null ? _hasUses : _hasUses.and(available);
  }

  /// Set a scope which contributes to determining this options availability.
  /// An option's availability is always governed by its [useCount] and
  /// [uses] in addition to the provided scope.
  ///
  /// See [isAvailable] and [availability].
  // TODO: move this to constructor
  void available(Scope scope) {
    _available = AndScope(scope, _hasUses);
  }

  /// Schedules option to be used at the end of the current event queue.
  ///
  /// The return future completes with success when the option is used and all
  /// listeners receive it. It completes with an error if the option is not
  /// available to be used.
  Future<UseOptionEvent> use() async {
    // Wait to check isAvailable until option actually about to be used
    var e = await _uses.event(() {
      if (!isAvailable) {
        throw OptionNotAvailableException(this);
      }

      return UseOptionEvent(this);
    });

    _useCount++;

    if (_useCount == uses) {
      _hasUses.exit();
    }

    return e;
  }

  String toString() => 'Option{'
      "text='$text',"
      'allowedUseCount=$uses,'
      'useCount=$_useCount'
      '}';
}

class OptionsUi {
  final Options _options;
  final Sink<Interaction> _interactions;

  OptionsUi(this._options, this._interactions);

  Stream<UiOption> get onOptionAvailable =>
      _options.onOptionAvailable.map((o) => UiOption(_interactions, o));
}

class UiOption {
  final Option _option;
  final Sink<Interaction> _interactions;

  String get text => _option.text;

  UiOption(this._interactions, this._option);

  void use() {
    _interactions.add(_UseOption(_option));
  }

  Stream<UiOption> get onUse => _option.onUse.map((e) => this);

  Stream<UiOption> get onUnavailable =>
      _option.availability.onExit.map((e) => this);
}

class _UseOption implements Interaction {
  final String moduleName = '$Options';
  final String name = '$_UseOption';

  Map<String, dynamic> _params;
  Map<String, dynamic> get parameters => _params;

  _UseOption(Option option) {
    _params = {'text': option.text};
  }

  static void run(Map<String, dynamic> parameters, Options options) {
    if (!parameters.containsKey('text')) {
      throw ArgumentError.value(
          parameters,
          'parameters',
          'Expected json to contain '
              '"text" field.');
    }

    var text = parameters['text'];
    var found =
        options._options.firstWhere((o) => o.text == text, orElse: () => null);

    if (found == null) {
      throw StateError('No option found from text "$text".');
    }

    found.use();
  }
}

class OptionsInteractor implements Interactor {
  final Options _options;

  OptionsInteractor(this._options);

  void run(String interaction, Map<String, dynamic> parameters) {
    if (interaction == '$_UseOption') {
      _UseOption.run(parameters, _options);
    } else {
      throw UnsupportedError('Unsupported interaction: $interaction');
    }
  }

  @override
  String get moduleName => '$Options';
}

class UseOptionEvent extends Event {
  final Option option;

  UseOptionEvent(this.option);
}

// Not sure if this should be error or exception
// Depends on context, so probably exception
class OptionNotAvailableException implements Exception {
  final Option option;

  OptionNotAvailableException(this.option);
}
