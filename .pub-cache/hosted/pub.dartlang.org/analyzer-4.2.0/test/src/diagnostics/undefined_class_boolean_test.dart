// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/error/codes.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../dart/resolution/context_collection_resolution.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UndefinedClassBooleanTest);
  });
}

@reflectiveTest
class UndefinedClassBooleanTest extends PubPackageResolutionTest {
  test_variableDeclaration() async {
    await assertErrorsInCode('''
f() { boolean v; }
''', [
      error(CompileTimeErrorCode.UNDEFINED_CLASS_BOOLEAN, 6, 7),
      error(HintCode.UNUSED_LOCAL_VARIABLE, 14, 1),
    ]);
  }
}
