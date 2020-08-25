// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';

class FakeFrameInfo implements FrameInfo {
  FakeFrameInfo(int width, int height, this._duration)
    : _image = FakeImage(width, height);

  final Duration _duration;
  final FakeImage _image;

  @override
  Duration get duration => _duration;

  @override
  Image get image => _image;

  bool get imageDisposed => _image.disposed;
}

class FakeImage implements Image {
  FakeImage(this._width, this._height);

  final int _width;
  final int _height;

  @override
  int get width => _width;

  @override
  int get height => _height;

  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
  }

  @override
  Future<ByteData> toByteData({ ImageByteFormat format = ImageByteFormat.rawRgba }) async {
    throw UnsupportedError('Cannot encode test image');
  }
}

class MockCodec implements Codec {

  @override
  int frameCount;

  @override
  int repetitionCount;

  int numFramesAsked = 0;

  Completer<FrameInfo> _nextFrameCompleter = Completer<FrameInfo>();

  @override
  Future<FrameInfo> getNextFrame() {
    numFramesAsked += 1;
    return _nextFrameCompleter.future;
  }

  void completeNextFrame(FrameInfo frameInfo) {
    _nextFrameCompleter.complete(frameInfo);
    _nextFrameCompleter = Completer<FrameInfo>();
  }

  void failNextFrame(String err) {
    _nextFrameCompleter.completeError(err);
  }

  @override
  void dispose() { }

}

class FakeEventReportingImageStreamCompleter extends ImageStreamCompleter {
  FakeEventReportingImageStreamCompleter({Stream<ImageChunkEvent> chunkEvents,}) {
    if (chunkEvents != null) {
      chunkEvents.listen((ImageChunkEvent event) {
          reportImageChunkEvent(event);
        },
      );
    }
  }
}

void main() {
  testWidgets('Codec future fails', (WidgetTester tester) async {
    final Completer<Codec> completer = Completer<Codec>();
    MultiFrameImageStreamCompleter(
      codec: completer.future,
      scale: 1.0,
    );
    completer.completeError('failure message');
    await tester.idle();
    expect(tester.takeException(), 'failure message');
  });

  testWidgets('Decoding starts when a listener is added after codec is ready', (WidgetTester tester) async {
    final Completer<Codec> completer = Completer<Codec>();
    final MockCodec mockCodec = MockCodec();
    mockCodec.frameCount = 1;
    final ImageStreamCompleter imageStream = MultiFrameImageStreamCompleter(
      codec: completer.future,
      scale: 1.0,
    );

    completer.complete(mockCodec);
    await tester.idle();
    expect(mockCodec.numFramesAsked, 0);

    final ImageListener listener = (ImageInfo image, bool synchronousCall) { };
    imageStream.addListener(ImageStreamListener(listener));
    await tester.idle();
    expect(mockCodec.numFramesAsked, 1);
  });

  testWidgets('Decoding starts when a codec is ready after a listener is added', (WidgetTester tester) async {
    final Completer<Codec> completer = Completer<Codec>();
    final MockCodec mockCodec = MockCodec();
    mockCodec.frameCount = 1;
    final ImageStreamCompleter imageStream = MultiFrameImageStreamCompleter(
      codec: completer.future,
      scale: 1.0,
    );

    final ImageListener listener = (ImageInfo image, bool synchronousCall) { };
    imageStream.addListener(ImageStreamListener(listener));
    await tester.idle();
    expect(mockCodec.numFramesAsked, 0);

    completer.complete(mockCodec);
    await tester.idle();
    expect(mockCodec.numFramesAsked, 1);
  });

  testWidgets('Chunk events of base ImageStreamCompleter are delivered', (WidgetTester tester) async {
    final List<ImageChunkEvent> chunkEvents = <ImageChunkEvent>[];
    final StreamController<ImageChunkEvent> streamController = StreamController<ImageChunkEvent>();
    final ImageStreamCompleter imageStream = FakeEventReportingImageStreamCompleter(
      chunkEvents: streamController.stream,
    );

    imageStream.addListener(ImageStreamListener(
      (ImageInfo image, bool synchronousCall) { },
      onChunk: (ImageChunkEvent event) {
        chunkEvents.add(event);
      },
    ));
    streamController.add(const ImageChunkEvent(cumulativeBytesLoaded: 1, expectedTotalBytes: 3));
    streamController.add(const ImageChunkEvent(cumulativeBytesLoaded: 2, expectedTotalBytes: 3));
    await tester.idle();

    expect(chunkEvents.length, 2);
    expect(chunkEvents[0].cumulativeBytesLoaded, 1);
    expect(chunkEvents[0].expectedTotalBytes, 3);
    expect(chunkEvents[1].cumulativeBytesLoaded, 2);
    expect(chunkEvents[1].expectedTotalBytes, 3);
  });

  testWidgets('Chunk events of base ImageStreamCompleter are not buffered before listener registration', (WidgetTester tester) async {
    final List<ImageChunkEvent> chunkEvents = <ImageChunkEvent>[];
    final StreamController<ImageChunkEvent> streamController = StreamController<ImageChunkEvent>();
    final ImageStreamCompleter imageStream = FakeEventReportingImageStreamCompleter(
      chunkEvents: streamController.stream,
    );

    streamController.add(const ImageChunkEvent(cumulativeBytesLoaded: 1, expectedTotalBytes: 3));
    await tester.idle();
    imageStream.addListener(ImageStreamListener(
      (ImageInfo image, bool synchronousCall) { },
      onChunk: (ImageChunkEvent event) {
        chunkEvents.add(event);
      },
    ));
    streamController.add(const ImageChunkEvent(cumulativeBytesLoaded: 2, expectedTotalBytes: 3));
    await tester.idle();

    expect(chunkEvents.length, 1);
    expect(chunkEvents[0].cumulativeBytesLoaded, 2);
    expect(chunkEvents[0].expectedTotalBytes, 3);
  });

  testWidgets('Chunk events of MultiFrameImageStreamCompleter are delivered', (WidgetTester tester) async {
    final List<ImageChunkEvent> chunkEvents = <ImageChunkEvent>[];
    final Completer<Codec> completer = Completer<Codec>();
    final StreamController<ImageChunkEvent> streamController = StreamController<ImageChunkEvent>();
    final ImageStreamCompleter imageStream = MultiFrameImageStreamCompleter(
      codec: completer.future,
      chunkEvents: streamController.stream,
      scale: 1.0,
    );

    imageStream.addListener(ImageStreamListener(
      (ImageInfo image, bool synchronousCall) { },
      onChunk: (ImageChunkEvent event) {
        chunkEvents.add(event);
      },
    ));
    streamController.add(const ImageChunkEvent(cumulativeBytesLoaded: 1, expectedTotalBytes: 3));
    streamController.add(const ImageChunkEvent(cumulativeBytesLoaded: 2, expectedTotalBytes: 3));
    await tester.idle();

    expect(chunkEvents.length, 2);
    expect(chunkEvents[0].cumulativeBytesLoaded, 1);
    expect(chunkEvents[0].expectedTotalBytes, 3);
    expect(chunkEvents[1].cumulativeBytesLoaded, 2);
    expect(chunkEvents[1].expectedTotalBytes, 3);
  });

  testWidgets('Chunk events of MultiFrameImageStreamCompleter are not buffered before listener registration', (WidgetTester tester) async {
    final List<ImageChunkEvent> chunkEvents = <ImageChunkEvent>[];
    final Completer<Codec> completer = Completer<Codec>();
    final StreamController<ImageChunkEvent> streamController = StreamController<ImageChunkEvent>();
    final ImageStreamCompleter imageStream = MultiFrameImageStreamCompleter(
      codec: completer.future,
      chunkEvents: streamController.stream,
      scale: 1.0,
    );

    streamController.add(const ImageChunkEvent(cumulativeBytesLoaded: 1, expectedTotalBytes: 3));
    await tester.idle();
    imageStream.addListener(ImageStreamListener(
      (ImageInfo image, bool synchronousCall) { },
      onChunk: (ImageChunkEvent event) {
        chunkEvents.add(event);
      },
    ));
    streamController.add(const ImageChunkEvent(cumulativeBytesLoaded: 2, expectedTotalBytes: 3));
    await tester.idle();

    expect(chunkEvents.length, 1);
    expect(chunkEvents[0].cumulativeBytesLoaded, 2);
    expect(chunkEvents[0].expectedTotalBytes, 3);
  });

  testWidgets('Chunk errors are reported', (WidgetTester tester) async {
    final List<ImageChunkEvent> chunkEvents = <ImageChunkEvent>[];
    final Completer<Codec> completer = Completer<Codec>();
    final StreamController<ImageChunkEvent> streamController = StreamController<ImageChunkEvent>();
    final ImageStreamCompleter imageStream = MultiFrameImageStreamCompleter(
      codec: completer.future,
      chunkEvents: streamController.stream,
      scale: 1.0,
    );

    imageStream.addListener(ImageStreamListener(
      (ImageInfo image, bool synchronousCall) { },
      onChunk: (ImageChunkEvent event) {
        chunkEvents.add(event);
      },
    ));
    streamController.addError(Error());
    streamController.add(const ImageChunkEvent(cumulativeBytesLoaded: 2, expectedTotalBytes: 3));
    await tester.idle();

    expect(tester.takeException(), isNotNull);
    expect(chunkEvents.length, 1);
    expect(chunkEvents[0].cumulativeBytesLoaded, 2);
    expect(chunkEvents[0].expectedTotalBytes, 3);
  });

  testWidgets('getNextFrame future fails', (WidgetTester tester) async {
    final MockCodec mockCodec = MockCodec();
    mockCodec.frameCount = 1;
    final Completer<Codec> codecCompleter = Completer<Codec>();

    final ImageStreamCompleter imageStream = MultiFrameImageStreamCompleter(
      codec: codecCompleter.future,
      scale: 1.0,
    );

    final ImageListener listener = (ImageInfo image, bool synchronousCall) { };
    imageStream.addListener(ImageStreamListener(listener));
    codecCompleter.complete(mockCodec);
    // MultiFrameImageStreamCompleter only sets an error handler for the next
    // frame future after the codec future has completed.
    // Idling here lets the MultiFrameImageStreamCompleter advance and set the
    // error handler for the nextFrame future.
    await tester.idle();

    mockCodec.failNextFrame('frame completion error');
    await tester.idle();

    expect(tester.takeException(), 'frame completion error');
  });

  testWidgets('ImageStream emits frame (static image)', (WidgetTester tester) async {
    final MockCodec mockCodec = MockCodec();
    mockCodec.frameCount = 1;
    final Completer<Codec> codecCompleter = Completer<Codec>();

    final ImageStreamCompleter imageStream = MultiFrameImageStreamCompleter(
      codec: codecCompleter.future,
      scale: 1.0,
    );

    final List<ImageInfo> emittedImages = <ImageInfo>[];
    imageStream.addListener(ImageStreamListener((ImageInfo image, bool synchronousCall) {
      emittedImages.add(image);
    }));

    codecCompleter.complete(mockCodec);
    await tester.idle();

    final FrameInfo frame = FakeFrameInfo(20, 10, const Duration(milliseconds: 200));
    mockCodec.completeNextFrame(frame);
    await tester.idle();

    expect(emittedImages, equals(<ImageInfo>[ImageInfo(image: frame.image)]));
  });

  testWidgets('ImageStream emits frames (animated images)', (WidgetTester tester) async {
    final MockCodec mockCodec = MockCodec();
    mockCodec.frameCount = 2;
    mockCodec.repetitionCount = -1;
    final Completer<Codec> codecCompleter = Completer<Codec>();

    final ImageStreamCompleter imageStream = MultiFrameImageStreamCompleter(
      codec: codecCompleter.future,
      scale: 1.0,
    );

    final List<ImageInfo> emittedImages = <ImageInfo>[];
    imageStream.addListener(ImageStreamListener((ImageInfo image, bool synchronousCall) {
      emittedImages.add(image);
    }));

    codecCompleter.complete(mockCodec);
    await tester.idle();

    final FrameInfo frame1 = FakeFrameInfo(20, 10, const Duration(milliseconds: 200));
    mockCodec.completeNextFrame(frame1);
    await tester.idle();
    // We are waiting for the next animation tick, so at this point no frames
    // should have been emitted.
    expect(emittedImages.length, 0);

    await tester.pump();
    expect(emittedImages, equals(<ImageInfo>[ImageInfo(image: frame1.image)]));

    final FrameInfo frame2 = FakeFrameInfo(200, 100, const Duration(milliseconds: 400));
    mockCodec.completeNextFrame(frame2);

    await tester.pump(const Duration(milliseconds: 100));
    // The duration for the current frame was 200ms, so we don't emit the next
    // frame yet even though it is ready.
    expect(emittedImages.length, 1);

    await tester.pump(const Duration(milliseconds: 100));
    expect(emittedImages, equals(<ImageInfo>[
      ImageInfo(image: frame1.image),
      ImageInfo(image: frame2.image),
    ]));

    // Let the pending timer for the next frame to complete so we can cleanly
    // quit the test without pending timers.
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('animation wraps back', (WidgetTester tester) async {
    final MockCodec mockCodec = MockCodec();
    mockCodec.frameCount = 2;
    mockCodec.repetitionCount = -1;
    final Completer<Codec> codecCompleter = Completer<Codec>();

    final ImageStreamCompleter imageStream = MultiFrameImageStreamCompleter(
      codec: codecCompleter.future,
      scale: 1.0,
    );

    final List<ImageInfo> emittedImages = <ImageInfo>[];
    imageStream.addListener(ImageStreamListener((ImageInfo image, bool synchronousCall) {
      emittedImages.add(image);
    }));

    codecCompleter.complete(mockCodec);
    await tester.idle();

    final FrameInfo frame1 = FakeFrameInfo(20, 10, const Duration(milliseconds: 200));
    final FrameInfo frame2 = FakeFrameInfo(200, 100, const Duration(milliseconds: 400));

    mockCodec.completeNextFrame(frame1);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(); // first animation frame shows on first app frame.
    mockCodec.completeNextFrame(frame2);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(const Duration(milliseconds: 200)); // emit 2nd frame.
    mockCodec.completeNextFrame(frame1);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(const Duration(milliseconds: 400)); // emit 3rd frame

    expect(emittedImages, equals(<ImageInfo>[
      ImageInfo(image: frame1.image),
      ImageInfo(image: frame2.image),
      ImageInfo(image: frame1.image),
    ]));

    // Let the pending timer for the next frame to complete so we can cleanly
    // quit the test without pending timers.
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('animation doesnt repeat more than specified', (WidgetTester tester) async {
    final MockCodec mockCodec = MockCodec();
    mockCodec.frameCount = 2;
    mockCodec.repetitionCount = 0;
    final Completer<Codec> codecCompleter = Completer<Codec>();

    final ImageStreamCompleter imageStream = MultiFrameImageStreamCompleter(
      codec: codecCompleter.future,
      scale: 1.0,
    );

    final List<ImageInfo> emittedImages = <ImageInfo>[];
    imageStream.addListener(ImageStreamListener((ImageInfo image, bool synchronousCall) {
      emittedImages.add(image);
    }));

    codecCompleter.complete(mockCodec);
    await tester.idle();

    final FrameInfo frame1 = FakeFrameInfo(20, 10, const Duration(milliseconds: 200));
    final FrameInfo frame2 = FakeFrameInfo(200, 100, const Duration(milliseconds: 400));

    mockCodec.completeNextFrame(frame1);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(); // first animation frame shows on first app frame.
    mockCodec.completeNextFrame(frame2);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(const Duration(milliseconds: 200)); // emit 2nd frame.
    mockCodec.completeNextFrame(frame1);
    // allow another frame to complete (but we shouldn't be asking for it as
    // this animation should not repeat.
    await tester.idle();
    await tester.pump(const Duration(milliseconds: 400));

    expect(emittedImages, equals(<ImageInfo>[
      ImageInfo(image: frame1.image),
      ImageInfo(image: frame2.image),
    ]));
  });

  testWidgets('frames are only decoded when there are active listeners', (WidgetTester tester) async {
    final MockCodec mockCodec = MockCodec();
    mockCodec.frameCount = 2;
    mockCodec.repetitionCount = -1;
    final Completer<Codec> codecCompleter = Completer<Codec>();

    final ImageStreamCompleter imageStream = MultiFrameImageStreamCompleter(
      codec: codecCompleter.future,
      scale: 1.0,
    );

    final ImageListener listener = (ImageInfo image, bool synchronousCall) { };
    imageStream.addListener(ImageStreamListener(listener));

    codecCompleter.complete(mockCodec);
    await tester.idle();

    final FrameInfo frame1 = FakeFrameInfo(20, 10, const Duration(milliseconds: 200));
    final FrameInfo frame2 = FakeFrameInfo(200, 100, const Duration(milliseconds: 400));

    mockCodec.completeNextFrame(frame1);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(); // first animation frame shows on first app frame.
    mockCodec.completeNextFrame(frame2);
    imageStream.removeListener(ImageStreamListener(listener));
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(const Duration(milliseconds: 400)); // emit 2nd frame.

    // Decoding of the 3rd frame should not start as there are no registered
    // listeners to the stream
    expect(mockCodec.numFramesAsked, 2);

    imageStream.addListener(ImageStreamListener(listener));
    await tester.idle(); // let nextFrameFuture complete
    expect(mockCodec.numFramesAsked, 3);
  });

  testWidgets('multiple stream listeners', (WidgetTester tester) async {
    final MockCodec mockCodec = MockCodec();
    mockCodec.frameCount = 2;
    mockCodec.repetitionCount = -1;
    final Completer<Codec> codecCompleter = Completer<Codec>();

    final ImageStreamCompleter imageStream = MultiFrameImageStreamCompleter(
      codec: codecCompleter.future,
      scale: 1.0,
    );

    final List<ImageInfo> emittedImages1 = <ImageInfo>[];
    final ImageListener listener1 = (ImageInfo image, bool synchronousCall) {
      emittedImages1.add(image);
    };
    final List<ImageInfo> emittedImages2 = <ImageInfo>[];
    final ImageListener listener2 = (ImageInfo image, bool synchronousCall) {
      emittedImages2.add(image);
    };
    imageStream.addListener(ImageStreamListener(listener1));
    imageStream.addListener(ImageStreamListener(listener2));

    codecCompleter.complete(mockCodec);
    await tester.idle();

    final FrameInfo frame1 = FakeFrameInfo(20, 10, const Duration(milliseconds: 200));
    final FrameInfo frame2 = FakeFrameInfo(200, 100, const Duration(milliseconds: 400));

    mockCodec.completeNextFrame(frame1);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(); // first animation frame shows on first app frame.
    expect(emittedImages1, equals(<ImageInfo>[ImageInfo(image: frame1.image)]));
    expect(emittedImages2, equals(<ImageInfo>[ImageInfo(image: frame1.image)]));

    mockCodec.completeNextFrame(frame2);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(); // next app frame will schedule a timer.
    imageStream.removeListener(ImageStreamListener(listener1));

    await tester.pump(const Duration(milliseconds: 400)); // emit 2nd frame.
    expect(emittedImages1, equals(<ImageInfo>[ImageInfo(image: frame1.image)]));
    expect(emittedImages2, equals(<ImageInfo>[
      ImageInfo(image: frame1.image),
      ImageInfo(image: frame2.image),
    ]));
  });

  testWidgets('timer is canceled when listeners are removed', (WidgetTester tester) async {
    final MockCodec mockCodec = MockCodec();
    mockCodec.frameCount = 2;
    mockCodec.repetitionCount = -1;
    final Completer<Codec> codecCompleter = Completer<Codec>();

    final ImageStreamCompleter imageStream = MultiFrameImageStreamCompleter(
      codec: codecCompleter.future,
      scale: 1.0,
    );

    final ImageListener listener = (ImageInfo image, bool synchronousCall) { };
    imageStream.addListener(ImageStreamListener(listener));

    codecCompleter.complete(mockCodec);
    await tester.idle();

    final FrameInfo frame1 = FakeFrameInfo(20, 10, const Duration(milliseconds: 200));
    final FrameInfo frame2 = FakeFrameInfo(200, 100, const Duration(milliseconds: 400));

    mockCodec.completeNextFrame(frame1);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(); // first animation frame shows on first app frame.

    mockCodec.completeNextFrame(frame2);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump();

    imageStream.removeListener(ImageStreamListener(listener));
    // The test framework will fail this if there are pending timers at this
    // point.
  });

  testWidgets('timeDilation affects animation frame timers', (WidgetTester tester) async {
    final MockCodec mockCodec = MockCodec();
    mockCodec.frameCount = 2;
    mockCodec.repetitionCount = -1;
    final Completer<Codec> codecCompleter = Completer<Codec>();

    final ImageStreamCompleter imageStream = MultiFrameImageStreamCompleter(
      codec: codecCompleter.future,
      scale: 1.0,
    );

    final ImageListener listener = (ImageInfo image, bool synchronousCall) { };
    imageStream.addListener(ImageStreamListener(listener));

    codecCompleter.complete(mockCodec);
    await tester.idle();

    final FrameInfo frame1 = FakeFrameInfo(20, 10, const Duration(milliseconds: 200));
    final FrameInfo frame2 = FakeFrameInfo(200, 100, const Duration(milliseconds: 400));

    mockCodec.completeNextFrame(frame1);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(); // first animation frame shows on first app frame.

    timeDilation = 2.0;
    mockCodec.completeNextFrame(frame2);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(); // schedule next app frame
    await tester.pump(const Duration(milliseconds: 200)); // emit 2nd frame.
    // Decoding of the 3rd frame should not start after 200 ms, as time is
    // dilated by a factor of 2.
    expect(mockCodec.numFramesAsked, 2);
    await tester.pump(const Duration(milliseconds: 200)); // emit 2nd frame.
    expect(mockCodec.numFramesAsked, 3);
  });

  testWidgets('error handlers can intercept errors', (WidgetTester tester) async {
    final MockCodec mockCodec = MockCodec();
    mockCodec.frameCount = 1;
    final Completer<Codec> codecCompleter = Completer<Codec>();

    final ImageStreamCompleter streamUnderTest = MultiFrameImageStreamCompleter(
      codec: codecCompleter.future,
      scale: 1.0,
    );

    dynamic capturedException;
    final ImageErrorListener errorListener = (dynamic exception, StackTrace stackTrace) {
      capturedException = exception;
    };

    streamUnderTest.addListener(ImageStreamListener(
      (ImageInfo image, bool synchronousCall) { },
      onError: errorListener,
    ));

    codecCompleter.complete(mockCodec);
    // MultiFrameImageStreamCompleter only sets an error handler for the next
    // frame future after the codec future has completed.
    // Idling here lets the MultiFrameImageStreamCompleter advance and set the
    // error handler for the nextFrame future.
    await tester.idle();

    mockCodec.failNextFrame('frame completion error');
    await tester.idle();

    // No exception is passed up.
    expect(tester.takeException(), isNull);
    expect(capturedException, 'frame completion error');
  });

  testWidgets('remove and add listener ', (WidgetTester tester) async {
    final MockCodec mockCodec = MockCodec();
    mockCodec.frameCount = 3;
    mockCodec.repetitionCount = 0;
    final Completer<Codec> codecCompleter = Completer<Codec>();

    final ImageStreamCompleter imageStream = MultiFrameImageStreamCompleter(
      codec: codecCompleter.future,
      scale: 1.0,
    );

    final ImageListener listener = (ImageInfo image, bool synchronousCall) { };
    imageStream.addListener(ImageStreamListener(listener));

    codecCompleter.complete(mockCodec);

    await tester.idle(); // let nextFrameFuture complete

    imageStream.removeListener(ImageStreamListener(listener));
    imageStream.addListener(ImageStreamListener(listener));


    final FrameInfo frame1 = FakeFrameInfo(20, 10, const Duration(milliseconds: 200));

    mockCodec.completeNextFrame(frame1);
    await tester.idle(); // let nextFrameFuture complete
    await tester.pump(); // first animation frame shows on first app frame.

    await tester.pump(const Duration(milliseconds: 200)); // emit 2nd frame.
  });

  testWidgets('ImageStreamListener hashCode and equals', (WidgetTester tester) async {
    void handleImage(ImageInfo image, bool synchronousCall) { }
    void handleImageDifferently(ImageInfo image, bool synchronousCall) { }
    void handleError(dynamic error, StackTrace stackTrace) { }
    void handleChunk(ImageChunkEvent event) { }

    void compare({
      @required ImageListener onImage1,
      @required ImageListener onImage2,
      ImageChunkListener onChunk1,
      ImageChunkListener onChunk2,
      ImageErrorListener onError1,
      ImageErrorListener onError2,
      bool areEqual = true,
    }) {
      final ImageStreamListener l1 = ImageStreamListener(onImage1, onChunk: onChunk1, onError: onError1);
      final ImageStreamListener l2 = ImageStreamListener(onImage2, onChunk: onChunk2, onError: onError2);
      Matcher comparison(dynamic expected) => areEqual ? equals(expected) : isNot(equals(expected));
      expect(l1, comparison(l2));
      expect(l1.hashCode, comparison(l2.hashCode));
    }

    compare(onImage1: handleImage, onImage2: handleImage);
    compare(onImage1: handleImage, onImage2: handleImageDifferently, areEqual: false);
    compare(onImage1: handleImage, onChunk1: handleChunk, onImage2: handleImage, onChunk2: handleChunk);
    compare(onImage1: handleImage, onChunk1: handleChunk, onError1: handleError, onImage2: handleImage, onChunk2: handleChunk, onError2: handleError);
    compare(onImage1: handleImage, onChunk1: handleChunk, onImage2: handleImage, areEqual: false);
    compare(onImage1: handleImage, onChunk1: handleChunk, onError1: handleError, onImage2: handleImage, areEqual: false);
    compare(onImage1: handleImage, onChunk1: handleChunk, onError1: handleError, onImage2: handleImage, onChunk2: handleChunk, areEqual: false);
    compare(onImage1: handleImage, onChunk1: handleChunk, onError1: handleError, onImage2: handleImage, onError2: handleError, areEqual: false);
  });

  testWidgets('disposes image when last listener drops - single frame', (WidgetTester tester) async {
    final FakeImage image = FakeImage(10, 10);
    expect(image.disposed, false);

    final ImageInfo imageInfo = ImageInfo(
      image: image,
      debugLabel: 'fakeImage',
    );
    final ImageStreamCompleter imageStream = OneFrameImageStreamCompleter(Future<ImageInfo>.value(imageInfo));
    expect(image.disposed, false);


    void listener(ImageInfo listenerImageInfo, bool syncCall) {
      expectSync(listenerImageInfo, isNotNull);
      expectSync(listenerImageInfo, imageInfo);
      expectSync(image.disposed, false);
    }
    expect(imageStream.hasListeners, false);

    imageStream.addListener(ImageStreamListener(listener));
    await tester.idle();
    expect(image.disposed, false);
    expect(imageStream.hasListeners, true);

    imageStream.removeListener(ImageStreamListener(listener));
    expect(imageStream.hasListeners, false);
    expect(image.disposed, true);
  });

  testWidgets('does not dispose image when last listener drops - single frame - keep alive', (WidgetTester tester) async {
    final FakeImage image = FakeImage(10, 10);
    expect(image.disposed, false);

    final ImageInfo imageInfo = ImageInfo(
      image: image,
      debugLabel: 'fakeImage',
      keepAlive: true,
    );
    final ImageStreamCompleter imageStream = OneFrameImageStreamCompleter(Future<ImageInfo>.value(imageInfo));
    expect(image.disposed, false);


    void listener(ImageInfo listenerImageInfo, bool syncCall) {
      expectSync(listenerImageInfo, isNotNull);
      expectSync(listenerImageInfo, imageInfo);
      expectSync(image.disposed, false);
    }
    expect(imageStream.hasListeners, false);

    imageStream.addListener(ImageStreamListener(listener));
    await tester.idle();
    expect(image.disposed, false);
    expect(imageStream.hasListeners, true);

    imageStream.removeListener(ImageStreamListener(listener));
    expect(imageStream.hasListeners, false);
    expect(image.disposed, false);
  });

  testWidgets('does not dispose image when last listener drops - multi frame frame count 1', (WidgetTester tester) async {
    final MockCodec mockCodec = MockCodec();
    mockCodec.frameCount = 1;
    mockCodec.repetitionCount = 0;
    final Completer<Codec> codecCompleter = Completer<Codec>();

    final ImageStreamCompleter imageStream = MultiFrameImageStreamCompleter(
      codec: codecCompleter.future,
      scale: 1.0,
    );

    ImageInfo currentImage;
    final ImageListener listener = (ImageInfo image, bool synchronousCall) {
      currentImage = image;
    };

    imageStream.addListener(ImageStreamListener(listener));

    codecCompleter.complete(mockCodec);
    await tester.idle();

    expect(currentImage, null);
    final FakeFrameInfo frame = FakeFrameInfo(20, 10, Duration.zero);
    mockCodec.completeNextFrame(frame);
    await tester.idle();

    expect(currentImage, isNotNull);

    expect(currentImage.image, frame.image);
    expect(frame.imageDisposed, false);

    imageStream.removeListener(ImageStreamListener(listener));
    expect(frame.imageDisposed, true);
  });

  testWidgets('does not dispose image when last listener drops and keepFramesAlive is true - multi frame frame count 1', (WidgetTester tester) async {
    final MockCodec mockCodec = MockCodec();
    mockCodec.frameCount = 1;
    mockCodec.repetitionCount = 0;
    final Completer<Codec> codecCompleter = Completer<Codec>();

    final ImageStreamCompleter imageStream = MultiFrameImageStreamCompleter(
      codec: codecCompleter.future,
      scale: 1.0,
      keepFramesAlive: true,
    );

    ImageInfo currentImage;
    final ImageListener listener = (ImageInfo image, bool synchronousCall) {
      currentImage = image;
    };

    imageStream.addListener(ImageStreamListener(listener));

    codecCompleter.complete(mockCodec);
    await tester.idle();

    expect(currentImage, null);
    final FakeFrameInfo frame = FakeFrameInfo(20, 10, Duration.zero);
    mockCodec.completeNextFrame(frame);
    await tester.idle();

    expect(currentImage, isNotNull);

    expect(currentImage.image, frame.image);
    expect(frame.imageDisposed, false);

    imageStream.removeListener(ImageStreamListener(listener));
    expect(frame.imageDisposed, false);
  });

  testWidgets('disposes image when last listener drops - multi frame', (WidgetTester tester) async {
    final MockCodec mockCodec = MockCodec();
    mockCodec.frameCount = 2;
    mockCodec.repetitionCount = 0;
    final Completer<Codec> codecCompleter = Completer<Codec>();

    final ImageStreamCompleter imageStream = MultiFrameImageStreamCompleter(
      codec: codecCompleter.future,
      scale: 1.0,
    );

    ImageInfo currentImage;
    final ImageListener listener = (ImageInfo image, bool synchronousCall) {
      currentImage = image;
    };

    imageStream.addListener(ImageStreamListener(listener));

    codecCompleter.complete(mockCodec);
    await tester.idle();

    expect(currentImage, null);
    final FakeFrameInfo frame1 = FakeFrameInfo(20, 10, Duration.zero);
    mockCodec.completeNextFrame(frame1);
    await tester.idle();
    await tester.pump();

    expect(currentImage, isNotNull);

    expect(currentImage.image, frame1.image);
    expect(frame1.imageDisposed, false);

    final FakeFrameInfo frame2 = FakeFrameInfo(10, 10, Duration.zero);
    mockCodec.completeNextFrame(frame2);
    await tester.idle();
    await tester.pump();

    expect(frame1.imageDisposed, true);
    expect(currentImage.image, frame2.image);
    expect(frame2.imageDisposed, false);

    imageStream.removeListener(ImageStreamListener(listener));
    expect(frame2.imageDisposed, true);
  });

  testWidgets('does not dispose image when last listener drops and keepFramesAlive is true - multi frame', (WidgetTester tester) async {
    final MockCodec mockCodec = MockCodec();
    mockCodec.frameCount = 2;
    mockCodec.repetitionCount = 0;
    final Completer<Codec> codecCompleter = Completer<Codec>();

    final ImageStreamCompleter imageStream = MultiFrameImageStreamCompleter(
      codec: codecCompleter.future,
      scale: 1.0,
      keepFramesAlive: true,
    );

    ImageInfo currentImage;
    final ImageListener listener = (ImageInfo image, bool synchronousCall) {
      currentImage = image;
    };

    imageStream.addListener(ImageStreamListener(listener));

    codecCompleter.complete(mockCodec);
    await tester.idle();

    expect(currentImage, null);
    final FakeFrameInfo frame1 = FakeFrameInfo(20, 10, Duration.zero);
    mockCodec.completeNextFrame(frame1);
    await tester.idle();
    await tester.pump();

    expect(currentImage, isNotNull);

    expect(currentImage.image, frame1.image);
    expect(frame1.imageDisposed, false);

    final FakeFrameInfo frame2 = FakeFrameInfo(10, 10, Duration.zero);
    mockCodec.completeNextFrame(frame2);
    await tester.idle();
    await tester.pump();

    expect(frame1.imageDisposed, false);
    expect(currentImage.image, frame2.image);
    expect(frame2.imageDisposed, false);

    imageStream.removeListener(ImageStreamListener(listener));
    expect(frame2.imageDisposed, false);
  });


  // TODO(amirh): enable this once WidgetTester supports flushTimers.
  // https://github.com/flutter/flutter/issues/30344
  // testWidgets('remove and add listener before a delayed frame is scheduled', (WidgetTester tester) async {
  //   final MockCodec mockCodec = MockCodec();
  //   mockCodec.frameCount = 3;
  //   mockCodec.repetitionCount = 0;
  //   final Completer<Codec> codecCompleter = Completer<Codec>();
  //
  //   final ImageStreamCompleter imageStream = MultiFrameImageStreamCompleter(
  //     codec: codecCompleter.future,
  //     scale: 1.0,
  //   );
  //
  //   final ImageListener listener = (ImageInfo image, bool synchronousCall) { };
  //   imageStream.addListener(ImageLoadingListener(listener));
  //
  //   codecCompleter.complete(mockCodec);
  //   await tester.idle();
  //
  //   final FrameInfo frame1 = FakeFrameInfo(20, 10, const Duration(milliseconds: 200));
  //   final FrameInfo frame2 = FakeFrameInfo(200, 100, const Duration(milliseconds: 400));
  //   final FrameInfo frame3 = FakeFrameInfo(200, 100, const Duration(milliseconds: 0));
  //
  //   mockCodec.completeNextFrame(frame1);
  //   await tester.idle(); // let nextFrameFuture complete
  //   await tester.pump(); // first animation frame shows on first app frame.
  //
  //   mockCodec.completeNextFrame(frame2);
  //   await tester.pump(const Duration(milliseconds: 100)); // emit 2nd frame.
  //
  //   tester.flushTimers();
  //
  //   imageStream.removeListener(listener);
  //   imageStream.addListener(ImageLoadingListener(listener));
  //
  //   mockCodec.completeNextFrame(frame3);
  //   await tester.idle(); // let nextFrameFuture complete
  //
  //   await tester.pump();
  // });
}
