// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/painting.dart';
import 'package:test/test.dart';

import '../rendering/rendering_tester.dart';
import 'mocks_for_image_cache.dart';

void main() {
  new TestRenderingFlutterBinding(); // initializes the imageCache

  test('Image cache', () async {
    const FakeImage image = const FakeImage(16, 16); // 1 KB.
    imageCache.maximumSize = 3.0;

    final TestImageInfo a = await extractOneFrame(const TestImageProvider(1, 1, image: image).resolve(ImageConfiguration.empty));
    expect(a.value, equals(1));
    final TestImageInfo b = await extractOneFrame(const TestImageProvider(1, 2, image: image).resolve(ImageConfiguration.empty));
    expect(b.value, equals(1));
    final TestImageInfo c = await extractOneFrame(const TestImageProvider(1, 3, image: image).resolve(ImageConfiguration.empty));
    expect(c.value, equals(1));
    final TestImageInfo d = await extractOneFrame(const TestImageProvider(1, 4, image: image).resolve(ImageConfiguration.empty));
    expect(d.value, equals(1));
    final TestImageInfo e = await extractOneFrame(const TestImageProvider(1, 5, image: image).resolve(ImageConfiguration.empty));
    expect(e.value, equals(1));
    final TestImageInfo f = await extractOneFrame(const TestImageProvider(1, 6, image: image).resolve(ImageConfiguration.empty));
    expect(f.value, equals(1));

    expect(f, equals(a));
    expect(imageCache.currentSize, 1.0);

    // cache still only has one entry in it: 1(1)

    final TestImageInfo g = await extractOneFrame(const TestImageProvider(2, 7, image: image).resolve(ImageConfiguration.empty));
    expect(g.value, equals(7));

    // cache has two entries in it: 1(1), 2(7)
    expect(imageCache.currentSize, 2.0);

    final TestImageInfo h = await extractOneFrame(const TestImageProvider(1, 8, image: image).resolve(ImageConfiguration.empty));
    expect(h.value, equals(1));

    // cache still has two entries in it: 2(7), 1(1)

    final TestImageInfo i = await extractOneFrame(const TestImageProvider(3, 9, image: image).resolve(ImageConfiguration.empty));
    expect(i.value, equals(9));

    // cache has three entries in it: 2(7), 1(1), 3(9)
    expect(imageCache.currentSize, 3.0);

    final TestImageInfo j = await extractOneFrame(const TestImageProvider(1, 10, image: image).resolve(ImageConfiguration.empty));
    expect(j.value, equals(1));

    // cache still has three entries in it: 2(7), 3(9), 1(1)

    final TestImageInfo k = await extractOneFrame(const TestImageProvider(4, 11, image: image).resolve(ImageConfiguration.empty));
    expect(k.value, equals(11));

    // cache has three entries: 3(9), 1(1), 4(11)

    final TestImageInfo l = await extractOneFrame(const TestImageProvider(1, 12, image: image).resolve(ImageConfiguration.empty));
    expect(l.value, equals(1));

    // cache has three entries: 3(9), 4(11), 1(1)

    final TestImageInfo m = await extractOneFrame(const TestImageProvider(2, 13, image: image).resolve(ImageConfiguration.empty));
    expect(imageCache.currentSize, 3.0);
    expect(m.value, equals(13));

    // cache has three entries: 4(11), 1(1), 2(13)

    final TestImageInfo n = await extractOneFrame(const TestImageProvider(3, 14, image: image).resolve(ImageConfiguration.empty));
    expect(n.value, equals(14));

    // cache has three entries: 1(1), 2(13), 3(14)

    final TestImageInfo o = await extractOneFrame(const TestImageProvider(4, 15, image: image).resolve(ImageConfiguration.empty));
    expect(o.value, equals(15));

    // cache has three entries: 2(13), 3(14), 4(15)

    final TestImageInfo p = await extractOneFrame(const TestImageProvider(1, 16, image: image).resolve(ImageConfiguration.empty));
    expect(p.value, equals(16));

    // cache has three entries: 3(14), 4(15), 1(16)

  });
}
