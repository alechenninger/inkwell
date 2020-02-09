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
    var option = Option(text, uses: uses)
      ..availability.onEnter.listen((e) {
        var option = e.owner as Option;
        _options.add(option);
        _availableOptCtrl.add(option);
      })
      ..availability.onExit.listen((e) {
        var option = e.owner as Option;
        _options.remove(option);
      });

    option.available(available ?? _default());

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

  final _hasUses = SettableScope<void>.notEntered();
  final _uses = StreamController<UseOptionEvent>.broadcast(sync: true);

  Option(this.text, {this.uses = 1}) {
    if (uses < 0) {
      throw ArgumentError.value(
          uses, 'allowedUseCount', 'Allowed use count must be non-negative.');
    }

    _available = ScopeAsValue(owner: this)..within(_hasUses);

    if (uses > 0) {
      _hasUses.enter(null);
    }
  }

  /// Set a scope which contributes to determining this options availability.
  /// An option's availability is always governed by its [useCount] and
  /// [uses] in addition to the provided scope.
  ///
  /// See [isAvailable] and [availability].
  // TODO: move this to constructor
  void available(Scope scope) {
    _available.within(AndScope(scope, _hasUses));
  }

  /// Schedules option to be used at the end of the current event queue.
  ///
  /// The return future completes with success when the option is used and all
  /// listeners receive it. It completes with an error if the option is not
  /// available to be used.
  Future<UseOptionEvent> use() {
    /*
    Could this be simpler?

    return Future(() {
      // notAvailable checks current state
      if (notAvailable) {
        throw "bad";
      }

      // Changes state synchronously
      _count.increment();

      // Listeners fire in microtasks?
      _uses.add(UseOptionEvent(this));
    });

    Difference with above is that, for one, when used up, availability does not
    exit until the event actually happens later. Availability is currently just
    to notify the UI. I believe this also lies as the scope can exit even though
    isAvailable still returns true? So it leaks the future state AFAICT because
    the scope change is synchronous, and availability as observable is only
    changed in a future.

    We're getting closer. This is a good find I think because it may prove the
    complexity is too high (to have a subtle bug like this).
     */

    if (_available.observed.nextValue == false) {
      return Future.error(OptionNotAvailableException(this));
    }

    _useCount += 1;

    if (_useCount == uses) {
      _hasUses.exit(null);
    }

    return Future(() {
      var event = UseOptionEvent(this);
      _uses.add(event);
      return event;
    });
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
