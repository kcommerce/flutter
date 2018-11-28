// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors;

import '../configuration/helpers.dart';
import '../configuration/pickers.dart';
import '../playground_demo.dart';

const String _demoWidgetName = 'CupertinoButton';

class CupertinoButtonDemo extends PlaygroundDemo {
  Color _color = Colors.blue;

  @override
  String tabName() => _demoWidgetName.toUpperCase();

  @override
  String codePreview() => '''
CupertinoButton(
  child: const Text('BUTTON'),
  color: ${codeSnippetForColor(_color)},
  onPressed: () {},
)
''';

  @override
  Widget configWidget(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ColorPicker(
          selectedValue: _color,
          onItemTapped: (Color color) {
            updateConfiguration(() {
              _color = color;
            });
          },
        ),
      ],
    );
  }

  @override
  Widget previewWidget(BuildContext context) {
    return Center(
      child: CupertinoButton(
        child: const Text('BUTTON'),
        color: _color,
        onPressed: () {},
      ),
    );
  }
}
