// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore: deprecated_member_use
import 'package:test_api/test_api.dart' hide TypeMatcher, isInstanceOf;

import '../../../raw/shader_warm_up.dart' as demo;

void main() {
  test('layers smoketest for raw/shader_warm_up.dart', () {
    demo.main();
  });
}
