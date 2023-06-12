// Copyright (c) 2017, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:built_value/serializer.dart';
import 'package:test/test.dart';

void main() {
  var serializers = Serializers();

  group('DateTime with known specifiedType', () {
    var data = DateTime.utc(1980, 1, 2, 3, 4, 5, 6, 7);
    var serialized = data.microsecondsSinceEpoch;
    var specifiedType = const FullType(DateTime);

    test('can be serialized', () {
      expect(serializers.serialize(data, specifiedType: specifiedType),
          serialized);
    });

    test('can be deserialized', () {
      expect(serializers.deserialize(serialized, specifiedType: specifiedType),
          data);
    });

    test('serialize throws if not UTC', () {
      expect(() => serializers.serialize(DateTime.now()),
          throwsA(const TypeMatcher<ArgumentError>()));
    });
  });

  group('DateTime with unknown specifiedType', () {
    var data = DateTime.utc(1980, 1, 2, 3, 4, 5, 6, 7);
    var serialized =
        json.decode(json.encode(['DateTime', data.microsecondsSinceEpoch]))
            as Object;
    var specifiedType = FullType.unspecified;

    test('can be serialized', () {
      expect(serializers.serialize(data, specifiedType: specifiedType),
          serialized);
    });

    test('can be deserialized', () {
      expect(serializers.deserialize(serialized, specifiedType: specifiedType),
          data);
    });
  });
}
