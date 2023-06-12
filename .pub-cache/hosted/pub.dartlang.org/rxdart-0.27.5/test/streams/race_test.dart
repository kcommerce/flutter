import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

Stream<int> getDelayedStream(int delay, int value) async* {
  final completer = Completer<void>();

  Timer(Duration(milliseconds: delay), () => completer.complete());

  await completer.future;

  yield value;
  yield value + 1;
  yield value + 2;
}

void main() {
  test('Rx.race', () async {
    final first = getDelayedStream(50, 1),
        second = getDelayedStream(60, 2),
        last = getDelayedStream(70, 3);
    var expected = 1;

    Rx.race([first, second, last]).listen(expectAsync1((result) {
      // test to see if the combined output matches
      expect(result.compareTo(expected++), 0);
    }, count: 3));
  });

  test('Rx.race.iterate.once', () async {
    var iterationCount = 0;

    final stream = Rx.race<int>(() sync* {
      ++iterationCount;
      yield Stream.value(1);
      yield Stream.value(2);
      yield Stream.value(3);
    }());

    await expectLater(
      stream,
      emitsInOrder(<dynamic>[1, emitsDone]),
    );
    expect(iterationCount, 1);
  });

  test('Rx.race.single.subscription', () async {
    final first = getDelayedStream(50, 1);

    final stream = Rx.race([first]);

    stream.listen(null);
    await expectLater(() => stream.listen(null), throwsA(isStateError));
  });

  test('Rx.race.asBroadcastStream', () async {
    final first = getDelayedStream(50, 1),
        second = getDelayedStream(60, 2),
        last = getDelayedStream(70, 3);

    final stream = Rx.race([first, second, last]).asBroadcastStream();

    // listen twice on same stream
    stream.listen(null);
    stream.listen(null);
    // code should reach here
    await expectLater(stream.isBroadcast, isTrue);
  });

  test('Rx.race.shouldThrowB', () async {
    final stream = Rx.race([Stream<void>.error(Exception('oh noes!'))]);

    // listen twice on same stream
    stream.listen(null,
        onError: expectAsync2(
            (Exception e, StackTrace s) => expect(e, isException)));
  });

  test('Rx.race.pause.resume', () async {
    final first = getDelayedStream(50, 1),
        second = getDelayedStream(60, 2),
        last = getDelayedStream(70, 3);

    late StreamSubscription<int> subscription;
    // ignore: deprecated_member_use
    subscription = Rx.race([first, second, last]).listen(expectAsync1((value) {
      expect(value, 1);

      subscription.cancel();
    }, count: 1));

    subscription.pause(Future<void>.delayed(const Duration(milliseconds: 80)));
  });

  test('Rx.race.empty', () {
    expect(Rx.race<int>(const []), emitsDone);
  });

  test('Rx.race.single', () {
    expect(
      Rx.race<int>([Stream.value(1)]),
      emitsInOrder(<Object>[
        1,
        emitsDone,
      ]),
    );
  });

  test('Rx.race.cancel.throws', () async {
    Stream<int> stream() {
      final controller = StreamController<int>();
      controller.onCancel = () async {
        throw Exception('Exception when cancelling!');
      };

      return Rx.race<int>([
        controller.stream,
        Rx.concat([
          Rx.timer(1, const Duration(milliseconds: 100)),
          Rx.timer(2, const Duration(milliseconds: 100)),
        ]),
      ]);
    }

    await expectLater(
      stream(),
      emitsInOrder(<Object>[1, emitsError(isException), 2, emitsDone]),
    );

    await expectLater(
      stream().take(1),
      emitsInOrder(<Object>[1, emitsDone]),
    );
  });
}
