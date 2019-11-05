// Copyright 2019-present the Flutter authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import 'package:flutter/material.dart';

import 'package:flutter_gallery/demo/rally/colors.dart';
import 'package:flutter_gallery/demo/rally/data.dart';

class RallyLineChart extends StatelessWidget {
  const RallyLineChart({ this.events = const <DetailedEventData>[] })  : assert(events != null);

  final List<DetailedEventData> events;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: RallyLineChartPainter(Theme.of(context).textTheme.body1, events));
  }
}

class RallyLineChartPainter extends CustomPainter {
  RallyLineChartPainter(this.labelStyle, this.events);

  final TextStyle labelStyle;

  // Events to plot on the line as points.
  final List<DetailedEventData> events;

  // Number of days to plot.
  // This is hardcoded to reflect the dummy data, but would be dynamic in a real
  // app.
  final int numDays = 52;

  // Beginning of window. The end is this plus numDays.
  // This is hardcoded to reflect the dummy data, but would be dynamic in a real
  // app.
  final DateTime startDate = DateTime.utc(2018, 12, 1);

  // Ranges uses to lerp the pixel points.
  // This is hardcoded to reflect the dummy data, but would be dynamic in a real
  // app.
  final double maxAmount = 3000; // minAmount is assumed to be 0

  // The number of milliseconds in a day. This is the inherit period fot the
  // points in this line.
  static const int millisInDay = 24 * 60 * 60 * 1000;

  // Amount to shift the tick drawing by so that the Sunday ticks do not start
  // on the edge.
  final int tickShift = 3;

  // Arbitrary unit of space for absolute positioned painting.
  final double space = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final double ticksTop = size.height - space * 5;
    final double labelsTop = size.height - space * 2;
    _drawLine(
      canvas,
      Rect.fromLTWH(0, 0, size.width, ticksTop),
    );
    _drawXAxisTicks(
      canvas,
      Rect.fromLTWH(0, ticksTop, size.width, labelsTop - ticksTop),
    );
    _drawXAxisLabels(
      canvas,
      Rect.fromLTWH(0, labelsTop, size.width, size.height - labelsTop),
    );
  }

  // Since we're only using fixed dummy data, we can set this to false. In a
  // real app we would have the data as part of the state and repaint when it's
  // changed.
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;

  void _drawLine(Canvas canvas, Rect rect) {
    final Paint linePaint = Paint()
      ..color = RallyColors.accountColor(2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Arbitrary value for the first point. In a real app, a wider range of
    // points would be used that go beyond the boundaries of the screen.
    double lastAmount = 800;

    // Try changing this value between 1, 7, 15, etc.
    const int smoothing = 7;

    // Align the points with equal deltas (1 day) as a cumulative sum.
    int startMillis = startDate.millisecondsSinceEpoch;
    final List<Offset> points = <Offset>[
      Offset(0, (maxAmount - lastAmount) / maxAmount * rect.height)
    ];
    for (int i = 0; i < numDays + smoothing; i++) {
      final int endMillis = startMillis + millisInDay * 1;
      final List<DetailedEventData> filteredEvents = events.where(
        (DetailedEventData e) {
          return startMillis <= e.date.millisecondsSinceEpoch && e.date.millisecondsSinceEpoch <= endMillis;
        },
      ).toList();
      lastAmount += sumOf<DetailedEventData>(filteredEvents, (DetailedEventData e) => e.amount);
      final double x = i / numDays * rect.width;
      final double y = (maxAmount - lastAmount) / maxAmount * rect.height;
      points.add(Offset(x, y));
      startMillis = endMillis;
    }

    final Path path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length - smoothing; i += smoothing) {
      final double x1 = points[i].dx;
      final double y1 = points[i].dy;
      final double x2 = (x1 + points[i + smoothing].dx) / 2;
      final double y2 = (y1 + points[i + smoothing].dy) / 2;
      path.quadraticBezierTo(x1, y1, x2, y2);
    }
    canvas.drawPath(path, linePaint);
  }

  /// Draw the X-axis increment markers at constant width intervals.
  void _drawXAxisTicks(Canvas canvas, Rect rect) {
    for (int i = 0; i < numDays; i++) {
      final double x = rect.width / numDays * i;
      canvas.drawRect(
        Rect.fromPoints(
          Offset(x, i % 7 == tickShift ? rect.top : rect.center.dy),
          Offset(x, rect.bottom),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = RallyColors.gray25,
      );
    }
  }

  /// Set X-axis labels under the X-axis increment markers.
  void _drawXAxisLabels(Canvas canvas, Rect rect) {
    final TextStyle selectedLabelStyle = labelStyle.copyWith(
      fontWeight: FontWeight.w700,
    );
    final TextStyle unselectedLabelStyle = labelStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: RallyColors.gray25,
    );

    final TextPainter leftLabel = TextPainter(
      text: TextSpan(text: 'AUGUST 2019', style: unselectedLabelStyle),
      textDirection: TextDirection.ltr,
    );
    leftLabel.layout();
    leftLabel.paint(canvas, Offset(rect.left + space / 2, rect.center.dy));

    final TextPainter centerLabel = TextPainter(
      text: TextSpan(text: 'SEPTEMBER 2019', style: selectedLabelStyle),
      textDirection: TextDirection.ltr,
    );
    centerLabel.layout();
    final double x = (rect.width - centerLabel.width) / 2;
    final double y = rect.center.dy;
    centerLabel.paint(canvas, Offset(x, y));

    final TextPainter rightLabel = TextPainter(
      text: TextSpan(text: 'OCTOBER 2019', style: unselectedLabelStyle),
      textDirection: TextDirection.ltr,
    );
    rightLabel.layout();
    rightLabel.paint(
      canvas,
      Offset(rect.right - centerLabel.width - space / 2, rect.center.dy),
    );
  }
}
