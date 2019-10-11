// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../base/file_system.dart';
import '../base/platform.dart';
import '../globals.dart';

/// A class for representing depfile formats.
class Depfile {
  /// Create a [Depfile] from a list of [input] files and [output] files.
  const Depfile(this.inputs, this.outputs);

  /// Parse the depfile contents from [file].
  ///
  /// If the syntax is invalid, returns an empty [Depfile].
  factory Depfile.parse(File file) {
    final String contents = file.readAsStringSync();
    final List<String> colonSeparated = contents.split(': ');
    if (colonSeparated.length != 2) {
      printError('Invalid depfile: ${file.path}');
      return const Depfile(<File>[], <File>[]);
    }
    final List<File> inputs = _processList(colonSeparated[1].trim());
    final List<File> outputs = _processList(colonSeparated[0].trim());
    return Depfile(inputs, outputs);
  }

  /// The input files for this depfile.
  final List<File> inputs;

  /// The output files for this depfile.
  final List<File> outputs;

  /// Given an [depfile] File, write the depfile contents.
  ///
  /// If either [inputs] or [outputs] is empty, does not write to the file.
  void writeToFile(File depfile) {
    if (inputs.isEmpty || outputs.isEmpty) {
      return;
    }
    final StringBuffer buffer = StringBuffer();
    _writeFilesToBuffer(outputs, buffer);
    buffer.write(': ');
    _writeFilesToBuffer(inputs, buffer);
    depfile.writeAsStringSync(buffer.toString());
  }

  void _writeFilesToBuffer(List<File> files, StringBuffer buffer) {
    for (File outputFile in files) {
      if (platform.isWindows) {
        // Paths in a depfile have to be escaped on windows.
        final String escapedPath = outputFile.path.replaceAll(r'\', r'\\');
        buffer.write(' $escapedPath');
      } else {
        buffer.write(' ${outputFile.path}');
      }
    }
  }

  static final RegExp _separatorExpr = RegExp(r'([^\\]) ');
  static final RegExp _escapeExpr = RegExp(r'\\(.)');

  static List<File> _processList(String rawText) {
    return rawText
    // Put every file on right-hand side on the separate line
        .replaceAllMapped(_separatorExpr, (Match match) => '${match.group(1)}\n')
        .split('\n')
    // Expand escape sequences, so that '\ ', for example,ß becomes ' '
        .map<String>((String path) => path.replaceAllMapped(_escapeExpr, (Match match) => match.group(1)).trim())
        .where((String path) => path.isNotEmpty)
        .toSet()
        .map((String path) => fs.file(path))
        .toList();
  }
}
