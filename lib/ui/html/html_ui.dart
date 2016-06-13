// Copyright (c) 2015, Alec Henninger. All rights reserved. Use of this source
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'dart:html';
import 'dart:collection';

import 'package:august/options.dart';

/// Quick hacked together UI
class SimpleHtmlUi {
  final HtmlElement _container;
  final HtmlElement _dialogContainer = new DivElement()..classes.add('dialogs');
  final HtmlElement _optionsContainer = new UListElement()
    ..classes.add('options');

  var _domQueue = new Queue<Function>();

  SimpleHtmlUi(this._container, OptionsUi options) {
    _container.children.addAll([_optionsContainer, _dialogContainer]);

    // TODO: Add options and dialog already present

//    dialog.dialog.listen(
//        (e) => _dialogContainer.children.add(_getDialogElement(e, dialog)));
//
//    dialog.narration
//        .listen((e) => _dialogContainer.children.add(new DivElement()
//          ..classes.add('narration')
//          ..innerHtml = e.narration));
//
//    dialog.clears.listen((e) {
//      _dialogContainer.children.clear();
//    });

    options.onOptionAvailable.listen((o) {
      _beforeNextPaint(() {
        _optionsContainer.children.add(new LIElement()
          ..children.add(new SpanElement()
            ..classes.add('option')
            ..attributes['name'] = _toId(o.text)
            ..innerHtml = o.text
            ..onClick.listen((_) => o.use())));
      });

      o.onUnavailable.first.then((o) {
        _beforeNextPaint(() {
          _optionsContainer.children.removeWhere(
              (e) => e.children[0].attributes['name'] == _toId(o.text));
        });
      });
    });
  }

  // TODO: not sure if this is really helping anything
  _beforeNextPaint(void domUpdate()) {
    _domQueue.add(domUpdate);
    window.animationFrame.then((_) {
      while (_domQueue.isNotEmpty) {
        _domQueue.removeFirst()();
      }
    });
  }
}

// DivElement _getDialogElement(DialogEvent e, DialogInterface dialog) {
//   var dialogElement = new DivElement()
//     ..classes.add('dialog')
//     ..id = _toId(e.name);
//
//   dialogElement.children.add(new DivElement()
//     ..classes.add('what')
//     ..innerHtml = '${e.dialog}');
//
//   if (e.to != null) {
//     dialogElement.children.insert(
//         0,
//         new DivElement()
//           ..classes.add('target')
//           ..innerHtml = "${e.to}");
//   }
//
//   if (e.from != null) {
//     dialogElement.children.insert(
//         0,
//         new DivElement()
//           ..classes.add('speaker')
//           ..innerHtml = e.to == null ? e.from : "${e.from} to...");
//   }
//
//   if (e.replies.available.isNotEmpty) {
//     var replied = false;
//
//     Iterable<DivElement> replies =
//         e.replies.available.map((r) => new LIElement()
//           ..children.add(new SpanElement()
//             ..classes.addAll(['reply', 'reply-available'])
//             ..innerHtml = r
//             ..onClick.first.then((clickEvent) {
//               if (!replied) dialog.reply(r, e);
//             })));
//
//     dialog.replies
//         .firstWhere((r) => r.dialogEvent.name == e.name)
//         .then((ReplyEvent r) {
//       replied = true;
//
//       for (var replyElement
//           in querySelectorAll("#${_toId(e.name)} .reply-available")) {
//         replyElement.classes.remove('reply-available');
//
//         if (replyElement.innerHtml == r.reply) {
//           replyElement.classes.add('reply-chosen');
//         } else {
//           replyElement.classes.add('reply-not-chosen');
//         }
//       }
//     });
//
//     dialogElement.children.add(new UListElement()
//       ..classes.add('replies')
//       ..children.addAll(replies));
//   }
//
//   return dialogElement;
// }

String _toId(String name) {
  return name.replaceAll(new RegExp("[ :\\[\\],\\?\\.!']"), '_');
}
