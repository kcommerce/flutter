// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'find.dart';
import 'message.dart';

/// A Flutter Driver command that reads the text from a given element.
class GetText extends CommandWithTarget {
  /// [finder] looks for an element that contains a piece of text.
  GetText(SerializableFinder finder, { Duration timeout }) : super(finder, timeout: timeout);

  /// Deserializes this command from the value generated by [serialize].
  GetText.deserialize(Map<String, dynamic> json) : super.deserialize(json);

  @override
  final String kind = 'get_text';
}

/// The result of the [GetText] command.
class GetTextResult extends Result {
  /// Creates a result with the given [text].
  GetTextResult(this.text);

  /// The text extracted by the [GetText] command.
  final String text;

  /// Deserializes the result from JSON.
  static GetTextResult fromJson(Map<String, dynamic> json) {
    return new GetTextResult(json['text']);
  }

  @override
  Map<String, dynamic> toJson() => <String, String>{
    'text': text,
  };
}

/// A Flutter Driver command that enters text into the currently focused widget.
class EnterText extends Command {
  /// Creates a command that enters text into the currently focused widget.
  EnterText(this.text, { Duration timeout }) : super(timeout: timeout);

  /// The text extracted by the [GetText] command.
  final String text;

  /// Deserializes this command from the value generated by [serialize].
  EnterText.deserialize(Map<String, dynamic> json)
      : text = json['text'],
        super.deserialize(json);

  @override
  final String kind = 'enter_text';

  @override
  Map<String, String> serialize() => super.serialize()..addAll(<String, String>{
    'text': text,
  });
}

/// The result of the [EnterText] command.
class EnterTextResult extends Result {
  /// Creates a successful result of entering the text.
  EnterTextResult();

  /// Deserializes the result from JSON.
  static EnterTextResult fromJson(Map<String, dynamic> json) {
    return new EnterTextResult();
  }

  @override
  Map<String, dynamic> toJson() => const <String, String>{};
}
