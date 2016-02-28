// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

library august.options;

import 'package:august/august.dart';
import 'package:august/ui.dart';

class Options {
  final StreamController<Option> _ctrl =
      new StreamController.broadcast(sync: true);
  final List<Option> _options = [];

  Stream<Option> get onOptionAvailable => _ctrl.stream;

  Option newOption(String text) {
    return new Option(text)
      ..availability.onEnter.listen((e) {
        var option = e.owner as Option;
        _options.add(option);
        _ctrl.add(option);
      });
  }
}

class Option {
  final String text;

  final int allowedUseCount;

  Observed<int> get useCount => _useCount;

  bool get isAvailable => _available.observed.value;

  /// A scope that is entered whenever this option is available.
  Scope<StateChangeEvent<bool>> get availability => _available.asScope;

  // TODO: Consider simply Stream<Option>
  Stream<UseOptionEvent> get onUse => _uses.stream;

  final SettableScope _hasUses = new SettableScope.notEntered();
  final StreamController _uses = new StreamController.broadcast(sync: true);
  Observable<int> _useCount;
  ScopeAsValue _available;

  Option(this.text, {this.allowedUseCount: 1}) {
    _useCount = new Observable.ofImmutable(0, owner: this);
    _available = new ScopeAsValue(owner: this);

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

  Future<UseOptionEvent> use() {
    if (_available.observed.nextValue == false) {
      return new Future.error(new OptionNotAvailableException(this));
    }

    _useCount.set((c) => c + 1);

    if (_useCount.nextValue == allowedUseCount) {
      _hasUses.exit(null);
    }

    return new Future(() {
      var event = new UseOptionEvent(this);
      _uses.add(event);
      return event;
    });
  }
}

class OptionsUi {
  final Options _options;
  final Sink<Interaction> _interactions;

  OptionsUi(this._options, this._interactions);

  Stream<UiOption> get onOptionAvailable => _options._ctrl.stream
      .map((o) => new UiOption(_options, _interactions, o));
}

class UiOption {
  final Options _options;
  final Option _option;
  final Sink<Interaction> _interactions;

  String get text => _option.text;

  UiOption(this._options, this._interactions, this._option);

  void use() {
    _interactions.add(new UseOption(_option));
  }
}

class UseOption implements Interaction {
  final Option _option;

  UseOption(this._option);

  factory UseOption.fromJson(Map<String, dynamic> json, Options options) {
    if (!json.containsKey('text')) {
      throw new ArgumentError.value(json, 'json', 'Expected json to contain '
          '"text" field.');
    }

    var text = json['text'];
    var found = options._options.firstWhere((o) => o.text == text, orElse: null);

    if (found == null) {
      throw new StateError('No option found from text "$text".');
    }

    return new UseOption(found);
  }

  Future run() => _option.use();

  Map<String, dynamic> toJson() => {
    "text": _option.text
  };
}

class UseOptionEvent {
  final Option option;

  UseOptionEvent(this.option);
}

class OptionNotAvailableException implements Exception {
  final Option option;

  OptionNotAvailableException(this.option);
}
