// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:meta/meta.dart';
import 'package:xml/xml.dart';
import 'package:yaml/yaml.dart';

import '../base/common.dart';
import '../base/deferred_component.dart';
import '../base/error_handling_io.dart';
import '../base/file_system.dart';
import '../base/terminal.dart';
import '../build_system/build_system.dart';
import '../globals.dart' as globals;
import '../project.dart';
import '../template.dart';

/// A class to configure and run deferred component setup verification checks
/// and tasks.
///
/// Once constructed, checks and tasks can be executed by calling the respective
/// methods. The results of the checks are stored internally and can be
/// displayed to the user by calling [displayResults].
abstract class DeferredComponentsValidator {
  /// The build environment that should be used to find the input files to run
  /// checks against.
  ///
  /// The checks in this class are meant to be used as part of a build process,
  /// so an environment should be available.
  final Environment env;

  /// When true, failed checks and tasks will result in [attemptToolExit]
  /// triggering [throwToolExit].
  final bool exitOnFail;

  /// The name of the golden file that tracks the latest loading units
  /// generated.
  @visibleForTesting
  static const String kDeferredComponentsGoldenFileName = 'deferred_components_golden.yaml';
  /// The directory in the build folder to generate missing/modified files into.
  @visibleForTesting
  static const String kDeferredComponentsTempDirectory = 'android_deferred_components_setup_files';

  final String _title;
  final Directory _outputDir;
  // Files that were newly generated by this validator.
  final List<String> _generatedFiles;
  // Existing files that were modified by this validator.
  final List<String> _modifiedFiles;
  // Files that were invalid and unable to be checked. These files are input
  // files that the validator tries to read rather than output files the
  // validator generates. The key is the file name and the value is the message
  // or reason it was invalid.
  final Map<String, String> _invalidFiles;
  // Output of the diff task.
  // TODO(garyq): implement the diff task.
  final List<String> _diffLines;
  // Tracks the new and missing loading units.
  Map<String, dynamic> _goldenComparisonResults;

  /// All files read by the validator.
  List<File> get inputs => _inputs;
  final List<File> _inputs;

  /// All files output by the validator.
  List<File> get outputs => _outputs;
  final List<File> _outputs;

  /// Returns true if there were any recommended changes that should
  /// be applied.
  ///
  /// Retuns false if no problems or recommendations were detected.
  ///
  /// If no checks are run, then this will default to false and will remain so
  /// until a failing check finishes running.
  bool get changesNeeded => _generatedFiles.isNotEmpty
    || _modifiedFiles.isNotEmpty
    || _invalidFiles.isNotEmpty
    || (_goldenComparisonResults != null && !(_goldenComparisonResults['match'] as bool));

  /// Handles the results of all executed checks by calling [displayResults] and
  /// [attemptToolExit].
  ///
  /// This should be called after all desired checks and tasks are executed.
  void handleResults() {
    displayResults();
    attemptToolExit();
  }

  static const String _thickDivider = '=================================================================================';
  static const String _thinDivider = '---------------------------------------------------------------------------------';

  /// Displays the results of this validator's executed checks and tasks in a
  /// human readable format.
  ///
  /// All checks that are desired should be run before calling this method.
  void displayResults() {
    if (changesNeeded) {
      env.logger.printStatus(_thickDivider);
      env.logger.printStatus(_title, indent: (_thickDivider.length - _title.length) ~/ 2, emphasis: true);
      env.logger.printStatus(_thickDivider);
      // Log any file reading/existence errors.
      if (_invalidFiles.isNotEmpty) {
        env.logger.printStatus('Errors checking the following files:\n', emphasis: true);
        for (final String key in _invalidFiles.keys) {
          env.logger.printStatus('  - $key: ${_invalidFiles[key]}\n');
        }
      }
      // Log diff file contents, with color highlighting
      if (_diffLines != null && _diffLines.isNotEmpty) {
        env.logger.printStatus('Diff between `android` and expected files:', emphasis: true);
        env.logger.printStatus('');
        for (final String line in _diffLines) {
          // We only care about diffs in files that have
          // counterparts.
          if (line.startsWith('Only in android')) {
            continue;
          }
          TerminalColor color = TerminalColor.grey;
          if (line.startsWith('+')) {
            color = TerminalColor.green;
          } else if (line.startsWith('-')) {
            color = TerminalColor.red;
          }
          env.logger.printStatus(line, color: color);
        }
        env.logger.printStatus('');
      }
      // Log any newly generated and modified files.
      if (_generatedFiles.isNotEmpty) {
        env.logger.printStatus('Newly generated android files:', emphasis: true);
        for (final String filePath in _generatedFiles) {
          final String shortenedPath = filePath.substring(env.projectDir.parent.path.length + 1);
          env.logger.printStatus('  - $shortenedPath', color: TerminalColor.grey);
        }
        env.logger.printStatus('');
      }
      if (_modifiedFiles.isNotEmpty) {
        env.logger.printStatus('Modified android files:', emphasis: true);
        for (final String filePath in _modifiedFiles) {
          final String shortenedPath = filePath.substring(env.projectDir.parent.path.length + 1);
          env.logger.printStatus('  - $shortenedPath', color: TerminalColor.grey);
        }
        env.logger.printStatus('');
      }
      if (_generatedFiles.isNotEmpty || _modifiedFiles.isNotEmpty) {
        env.logger.printStatus('''
The above files have been placed into `build/$kDeferredComponentsTempDirectory`,
a temporary directory. The files should be reviewed and moved into the project's
`android` directory.''');
        if (_diffLines != null && _diffLines.isNotEmpty && !globals.platform.isWindows) {
          env.logger.printStatus(r'''

The recommended changes can be quickly applied by running:

  $ patch -p0 < build/setup_deferred_components.diff
''');
        }
        env.logger.printStatus('$_thinDivider\n');
      }
      // Log loading unit golden changes, if any.
      if (_goldenComparisonResults != null) {
        if ((_goldenComparisonResults['new'] as List<LoadingUnit>).isNotEmpty) {
          env.logger.printStatus('New loading units were found:', emphasis: true);
          for (final LoadingUnit unit in _goldenComparisonResults['new'] as List<LoadingUnit>) {
            env.logger.printStatus(unit.toString(), color: TerminalColor.grey, indent: 2);
          }
          env.logger.printStatus('');
        }
        if ((_goldenComparisonResults['missing'] as Set<LoadingUnit>).isNotEmpty) {
          env.logger.printStatus('Previously existing loading units no longer exist:', emphasis: true);
          for (final LoadingUnit unit in _goldenComparisonResults['missing'] as Set<LoadingUnit>) {
            env.logger.printStatus(unit.toString(), color: TerminalColor.grey, indent: 2);
          }
          env.logger.printStatus('');
        }
        if (_goldenComparisonResults['match'] as bool) {
          env.logger.printStatus('No change in generated loading units.\n');
        } else {
          env.logger.printStatus('''
It is recommended to verify that the changed loading units are expected
and to update the `deferred-components` section in `pubspec.yaml` to
incorporate any changes. The full list of generated loading units can be
referenced in the $kDeferredComponentsGoldenFileName file located alongside
pubspec.yaml.

This loading unit check will not fail again on the next build attempt
if no additional changes to the loading units are detected.
$_thinDivider\n''');
        }
      }
      // TODO(garyq): Add link to web tutorial/guide once it is written.
      env.logger.printStatus('''
Setup verification can be skipped by passing the `--no-verify-deferred-components`
flag, however, doing so may put your app at risk of not functioning even if the
build is successful.
$_thickDivider''');
      return;
    }
    env.logger.printStatus('$_title passed.');
  }

  void attemptToolExit() {
    if (exitOnFail && changesNeeded) {
      throwToolExit('Setup for deferred components incomplete. See recommended actions.', exitCode: 1);
    }
  }
}
