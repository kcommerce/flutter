// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

assertStatement() {
  late int v;
  assert((v = 0) >= 0, v);
  /*unassigned*/ v;
}
