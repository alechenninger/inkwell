// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:august/august.dart';

class Options {
  final _availableOptCtrl = StreamController<Option>();
  final _options = <Option>[];
  final GetScope _default;

  Options({GetScope defaultScope = getAlways}) : _default = defaultScope;

  Stream<Option> get _onOptionAvailable => _availableOptCtrl.stream;

  // TODO: OptionGroup exclusive()
  // var a = exclusive.

  Option oneTime(String text, {Scope available}) {
    return limitedUse(text, available: available, exclusiveWith: CountScope(1));
  }

  /// Creates a new limited use option that can be used while [available] and
  /// has remaining [exclusiveWith].
  Option limitedUse(String text, {Scope available, CountScope exclusiveWith}) {
    // TODO: Could just pass scope here and keep track of use state in closure
    var option =
        Option._(this, text, uses: exclusiveWith, available: available ?? _default());

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

  int get maxUses => uses.max;
  int get useCount => uses.count;

  Scope _available;

  bool get isAvailable => _available.isEntered;

  /// A scope that is entered whenever this option is available.
  Scope get availability => _available;

  // TODO: Consider simply Stream<Option>
  Stream<UseOptionEvent> get onUse => _onUse.stream;

  final CountScope uses;
  final _onUse = Events<UseOptionEvent>();
  final Options _options;

  Option._(this._options, this.text,
      {CountScope uses, Scope available = always})
      : uses = uses ?? CountScope(1) {
    _available = available.and(this.uses);
  }

  /// Schedules option to be used at the end of the current event queue.
  ///
  /// The return future completes with success when the option is used and all
  /// listeners receive it. It completes with an error if the option is not
  /// available to be used.
  Future<UseOptionEvent> use() async {
    // Wait to check isAvailable until option actually about to be used
    var e = await _onUse.event(() {
      if (!isAvailable) {
        throw OptionNotAvailableException(this);
      }

      return UseOptionEvent(this);
    });

    uses.increment();

    return e;
  }

  Option exclusiveWith(String text, {Scope available}) {
    return _options.limitedUse(text, exclusiveWith: uses, available: available);
  }

  String toString() => 'Option{'
      "text='$text',"
      'allowedUseCount=$maxUses,'
      'useCount=$useCount'
      '}';
}

class OptionsUi {
  final Options _options;
  final Sink<Interaction> _interactions;

  OptionsUi(this._options, this._interactions);

  Stream<UiOption> get onOptionAvailable =>
      _options._onOptionAvailable.map((o) => UiOption(_interactions, o));
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
