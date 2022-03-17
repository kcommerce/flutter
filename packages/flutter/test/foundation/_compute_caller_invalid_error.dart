// Copyright 2022 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// A test script that invokes compute() to start an isolate.

import 'dart:isolate';

import 'package:flutter/src/foundation/_isolates_io.dart';

int getLength(String s) {
  final ReceivePort r = ReceivePort();
  try {
    throw r;
  } finally {
    r.close();
  }
}

Future<void> main() async {
  const String s = 'hello world';

  bool wasError = false;
  try {
    await compute(getLength, s);
  } on RemoteError {
    wasError = true;
  }
  if (!wasError) {
    throw Exception('compute threw bad result');
  }
}
