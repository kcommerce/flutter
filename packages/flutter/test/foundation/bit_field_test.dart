// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:test/test.dart';

enum _TestEnum {
  a, b, c, d, e, f, g, h,
}

void main() {
  test('BitField control test', () {
    BitField<_TestEnum> field = new BitField<_TestEnum>(8);

    expect(field[_TestEnum.d], isFalse);

    field[_TestEnum.d] = true;
    field[_TestEnum.e] = true;

    expect(field[_TestEnum.c], isFalse);
    expect(field[_TestEnum.d], isTrue);
    expect(field[_TestEnum.e], isTrue);

    field[_TestEnum.e] = false;

    expect(field[_TestEnum.c], isFalse);
    expect(field[_TestEnum.d], isTrue);
    expect(field[_TestEnum.e], isFalse);

    field.reset();

    expect(field[_TestEnum.c], isFalse);
    expect(field[_TestEnum.d], isFalse);
    expect(field[_TestEnum.e], isFalse);

    field.reset(true);

    expect(field[_TestEnum.c], isTrue);
    expect(field[_TestEnum.d], isTrue);
    expect(field[_TestEnum.e], isTrue);
  });

  test('BitField.filed control test', () {
    BitField<_TestEnum> field1 = new BitField<_TestEnum>.filled(8, true);

    expect(field1[_TestEnum.d], isTrue);

    BitField<_TestEnum> field2 = new BitField<_TestEnum>.filled(8, false);

    expect(field2[_TestEnum.d], isFalse);
  });
}
