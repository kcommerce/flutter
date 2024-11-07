// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_api_samples/material/color_scheme/dynamic_content_color.0.dart' as example;
import 'package:flutter_test/flutter_test.dart';

void main() {
  // // The app being tested loads images via HTTP which the test
  // // framework defeats by default.
  // setUpAll(() {
  //   HttpOverrides.global = null;
  // });

  testWidgets('The theme colors are created dynamically from the first image', (WidgetTester tester) async {
    await HttpOverrides.runZoned(
      () async {
        await tester.runAsync(() async {
          await tester.pumpWidget(
            const example.DynamicColorExample(),
          );

          await tester.idle();
        });

        expect(find.widgetWithText(AppBar, 'Content Based Dynamic Color'), findsOne);

        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pumpAndSettle();
        expect(find.byType(Image), findsExactly(6));

        final ThemeData themeData = Theme.of(tester.element(find.byType(Scaffold)));

        print(themeData.primaryColor.value.toRadixString(16));
        expect(themeData.primaryColor, const Color(0xff575992));
      },
      createHttpClient: (SecurityContext? securityContext) => _FakeClient(),
    );
  });
}

class _FakeClient extends Fake implements HttpClient {
  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _FakeHttpClientRequest();
  }

  @override
  bool autoUncompress = true;
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async {
    return _FakeHttpClientResponse();
  }
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {}

class _FakeHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  int get contentLength => _blueSquarePng.length;

  @override
  int get statusCode => 200;

  @override
  Future<E> drain<E>([E? futureValue]) {
    return Future<E>.value(futureValue as E);
  }

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
          return Stream<List<int>>.value(_blueSquarePng).listen(
            onData,
            onDone: onDone,
            onError: onError,
            cancelOnError: cancelOnError,
          );

  }
}


/// A 50x50 blue square png.
final Uint8List _blueSquarePng =    Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x32, 0x00, 0x00, 0x00, 0x32, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1e, 0x3f, 0x88, 0xb1, 0x00, 0x00, 0x00, 0x48, 0x49, 0x44,
  0x41, 0x54, 0x78, 0xda, 0xed, 0xcf, 0x31, 0x0d, 0x00, 0x30, 0x08, 0x00, 0xb0,
  0x61, 0x63, 0x2f, 0xfe, 0x2d, 0x61, 0x05, 0x34, 0xf0, 0x92, 0xd6, 0x41, 0x23,
  0x7f, 0xf5, 0x3b, 0x20, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44,
  0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44,
  0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44, 0x44,
  0x44, 0x44, 0x44, 0x36, 0x06, 0x03, 0x6e, 0x69, 0x47, 0x12, 0x8e, 0xea, 0xaa,
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82,
]);
