// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'message.dart';

/// A Flutter Driver command that enables or disables semantics.
class SetSemantics extends Command {
  /// Creates a command that enables or disables semantics.
  const SetSemantics(this.enabled, { Duration timeout }) : super(timeout: timeout);

  /// Deserializes this command from the value generated by [serialize].
  SetSemantics.deserialize(Map<String, String> params)
    : enabled = params['enabled'].toLowerCase() == 'true',
      super.deserialize(params);

  /// Whether semantics should be enabled (true) or disabled (false).
  final bool enabled;

  @override
  String get kind => 'set_semantics';

  @override
  Map<String, String> serialize() => super.serialize()..addAll(<String, String>{
    'enabled': '$enabled',
  });
}

/// The result of a [SetSemantics] command.
class SetSemanticsResult extends Result {
  /// Create a result with the given [changedState].
  const SetSemanticsResult(this.changedState);

  /// Whether the [SetSemantics] command actually changed the state that the
  /// application was in.
  final bool changedState;

  /// Deserializes this result from JSON.
  static SetSemanticsResult fromJson(Map<String, dynamic> json) {
    return SetSemanticsResult(json['changedState'] as bool);
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'changedState': changedState,
  };
}
