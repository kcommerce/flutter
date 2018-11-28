// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../configuration/helpers.dart';
import '../configuration/pickers.dart';
import '../playground_demo.dart';

const String _demoWidgetName = 'Switch';

class SwitchDemo extends PlaygroundDemo {
  Color _activeColor = Colors.blue;
  Color _activeTrackColor = Colors.blue;
  Color _inactiveTrackColor = Colors.blue;
  bool _previewValue = true;

  @override
  String tabName() => _demoWidgetName.toUpperCase();

  @override
  String codePreview() => '''
Switch(
  value: $_previewValue,
  activeColor: ${codeSnippetForColor(_activeColor)},
  activeTrackColor: ${codeSnippetForColor(_activeTrackColor)},
  inactiveTrackColor: ${codeSnippetForColor(_inactiveTrackColor)},
  onChanged: (bool value) {},
)
''';

  @override
  Widget configWidget(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ColorPicker(
          label: 'Active Color',
          selectedValue: _activeColor,
          onItemTapped: (Color color) {
            updateConfiguration(() {
              _activeColor = color;
            });
          },
        ),
        ColorPicker(
          label: 'Active Track Color',
          selectedValue: _activeTrackColor,
          onItemTapped: (Color color) {
            updateConfiguration(() {
              _activeTrackColor = color;
            });
          },
        ),
        ColorPicker(
          label: 'Inactive Track Color',
          selectedValue: _inactiveTrackColor,
          onItemTapped: (Color color) {
            updateConfiguration(() {
              _inactiveTrackColor = color;
            });
          },
        ),
      ],
    );
  }

  @override
  Widget previewWidget(BuildContext context) {
    return Center(
      child: Switch(
        value: _previewValue,
        activeColor: _activeColor,
        activeTrackColor: _activeTrackColor,
        inactiveTrackColor: _inactiveTrackColor,
        onChanged: (bool value) {
          updateConfiguration(() {
            _previewValue = value;
          });
        },
      ),
    );
  }
}
