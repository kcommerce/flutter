// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// @dart = 2.8

import 'package:meta/meta.dart';
import 'package:xml/xml.dart';

import '../base/common.dart';
import '../base/deferred_component.dart';
import '../base/error_handling_io.dart';
import '../base/file_system.dart';
import '../base/terminal.dart';
import '../build_system/build_system.dart';
import '../globals.dart' as globals;
import '../project.dart';
import '../template.dart';
import 'deferred_components_validator.dart';

/// A class to configure and run deferred component setup verification checks
/// and tasks.
///
/// Once constructed, checks and tasks can be executed by calling the respective
/// methods. The results of the checks are stored internally and can be
/// displayed to the user by calling [displayResults].
class DeferredComponentsPrebuildValidator extends DeferredComponentsValidator {
  /// Constructs a validator instance.
  ///
  /// The [env] property is used to locate the project files that are checked.
  ///
  /// The [templatesDir] parameter is optional. If null, the tool's default
  /// templates directory will be used.
  ///
  /// When [exitOnFail] is set to true, the [handleResults] and [attemptToolExit]
  /// methods will exit the tool when this validator detects a recommended
  /// change. This defaults to true.
  DeferredComponentsPrebuildValidator(this.env, {
    this.exitOnFail = true,
    String title,
    Directory templatesDir,
  }) : _outputDir = env.projectDir
        .childDirectory('build')
        .childDirectory(kDeferredComponentsTempDirectory),
      _inputs = <File>[],
      _outputs = <File>[],
      _title = title ?? 'Deferred components setup verification',
      _templatesDir = templatesDir,
      _generatedFiles = <String>[],
      _modifiedFiles = <String>[],
      _invalidFiles = <String, String>{},
      _diffLines = <String>[];

  final Directory _templatesDir;

  /// Checks if an android dynamic feature module exists for each deferred
  /// component.
  ///
  /// Returns true if the check passed with no recommended changes, and false
  /// otherwise.
  ///
  /// This method looks for the existence of `android/<componentname>/build.gradle`
  /// and `android/<componentname>/src/main/AndroidManifest.xml`. If either of
  /// these files does not exist, it will generate it in the validator output
  /// directory based off of a template.
  ///
  /// This method does not check if the contents of either of the files are
  /// valid, as there are many ways that they can be validly configured.
  Future<bool> checkAndroidDynamicFeature(List<DeferredComponent> components) async {
    _inputs.add(env.projectDir.childFile('pubspec.yaml'));
    if (components == null || components.isEmpty) {
      return false;
    }
    bool changesMade = false;
    for (final DeferredComponent component in components) {
      final _DeferredComponentAndroidFiles androidFiles = _DeferredComponentAndroidFiles(
        name: component.name,
        env: env,
        templatesDir: _templatesDir
      );
      if (!androidFiles.verifyFilesExist()) {
        // generate into temp directory
        final Map<String, List<File>> results =
          await androidFiles.generateFiles(
            alternateAndroidDir: _outputDir,
            clearAlternateOutputDir: true,
          );
        for (final File file in results['outputs']) {
          _generatedFiles.add(file.path);
          changesMade = true;
        }
        _outputs.addAll(results['outputs']);
        _inputs.addAll(results['inputs']);
      }
    }
    return !changesMade;
  }

  /// Checks if the base module `app`'s `strings.xml` contain string
  /// resources for each component's name.
  ///
  /// Returns true if the check passed with no recommended changes, and false
  /// otherwise.
  ///
  /// In each dynamic feature module's AndroidManifest.xml, the
  /// name of the module is a string resource. This checks if
  /// the needed string resources are in the base module `strings.xml`.
  /// If not, this method will generate a modified `strings.xml` (or a
  /// completely new one if the original file did not exist) in the
  /// validator's output directory.
  ///
  /// For example, if there is a deferred component named `component1`,
  /// there should be the following string resource:
  ///
  ///   <string name="component1Name">component1</string>
  ///
  /// The string element's name attribute should be the component name with
  /// `Name` as a suffix, and the text contents should be the component name.
  bool checkAndroidResourcesStrings(List<DeferredComponent> components) {
    final Directory androidDir = env.projectDir.childDirectory('android');
    _inputs.add(env.projectDir.childFile('pubspec.yaml'));

    // Add component name mapping to strings.xml
    final File stringRes = androidDir
      .childDirectory('app')
      .childDirectory('src')
      .childDirectory('main')
      .childDirectory('res')
      .childDirectory('values')
      .childFile('strings.xml');
    _inputs.add(stringRes);
    final File stringResOutput = _outputDir
      .childDirectory('app')
      .childDirectory('src')
      .childDirectory('main')
      .childDirectory('res')
      .childDirectory('values')
      .childFile('strings.xml');
    ErrorHandlingFileSystem.deleteIfExists(stringResOutput);
    if (components == null || components.isEmpty) {
      return true;
    }
    final Map<String, String> requiredEntriesMap  = <String, String>{};
    for (final DeferredComponent component in components) {
      requiredEntriesMap['${component.name}Name'] = component.name;
    }
    if (stringRes.existsSync()) {
      bool modified = false;
      XmlDocument document;
      try {
        document = XmlDocument.parse(stringRes.readAsStringSync());
      } on XmlParserException {
        _invalidFiles[stringRes.path] = 'Error parsing $stringRes '
        'Please ensure that the strings.xml is a valid XML document and '
        'try again.';
        return false;
      }
      // Check if all required lines are present, and fix if name exists, but
      // wrong string stored.
      for (final XmlElement resources in document.findAllElements('resources')) {
        for (final XmlElement element in resources.findElements('string')) {
          final String name = element.getAttribute('name');
          if (requiredEntriesMap.containsKey(name)) {
            if (element.text != null && element.text != requiredEntriesMap[name]) {
              element.innerText = requiredEntriesMap[name];
              modified = true;
            }
            requiredEntriesMap.remove(name);
          }
        }
        for (final String key in requiredEntriesMap.keys) {
          modified = true;
          final XmlElement newStringElement = XmlElement(
            XmlName.fromString('string'),
            <XmlAttribute>[
              XmlAttribute(XmlName.fromString('name'), key),
            ],
            <XmlNode>[
              XmlText(requiredEntriesMap[key]),
            ],
          );
          resources.children.add(newStringElement);
        }
        break;
      }
      if (modified) {
        stringResOutput.createSync(recursive: true);
        stringResOutput.writeAsStringSync(document.toXmlString(pretty: true));
        _modifiedFiles.add(stringResOutput.path);
        return false;
      }
      return true;
    }
    // strings.xml does not exist, generate completely new file.
    stringResOutput.createSync(recursive: true);
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('''
<?xml version="1.0" encoding="utf-8"?>
<resources>
''');
    for (final String key in requiredEntriesMap.keys) {
      buffer.write('    <string name="$key">${requiredEntriesMap[key]}</string>\n');
    }
    buffer.write(
'''
</resources>

''');
    stringResOutput.writeAsStringSync(buffer.toString(), flush: true, mode: FileMode.append);
    _generatedFiles.add(stringResOutput.path);
    return false;
  }

  /// Deletes all files inside of the validator's output directory.
  void clearOutputDir() {
    final Directory dir = env.projectDir.childDirectory('build').childDirectory(kDeferredComponentsTempDirectory);
    ErrorHandlingFileSystem.deleteIfExists(dir, recursive: true);
  }
}

// Handles a single deferred component's android dynamic feature module
// directory.
class _DeferredComponentAndroidFiles {
  _DeferredComponentAndroidFiles({
    @required this.name,
    @required this.env,
    Directory templatesDir,
  }) : _templatesDir = templatesDir;

  // The name of the deferred component.
  final String name;
  final Environment env;
  final Directory _templatesDir;

  Directory get androidDir => env.projectDir.childDirectory('android');
  Directory get componentDir => androidDir.childDirectory(name);

  File get androidManifestFile => componentDir.childDirectory('src').childDirectory('main').childFile('AndroidManifest.xml');
  File get buildGradleFile => componentDir.childFile('build.gradle');

  // True when AndroidManifest.xml and build.gradle exist for the android dynamic feature.
  bool verifyFilesExist() {
    return androidManifestFile.existsSync() && buildGradleFile.existsSync();
  }

  // Generates any missing basic files for the dynamic feature into a temporary directory.
  Future<Map<String, List<File>>> generateFiles({Directory alternateAndroidDir, bool clearAlternateOutputDir = false}) async {
    final Directory outputDir = alternateAndroidDir?.childDirectory(name) ?? componentDir;
    if (clearAlternateOutputDir && alternateAndroidDir != null) {
      ErrorHandlingFileSystem.deleteIfExists(outputDir);
    }
    final List<File> inputs = <File>[];
    inputs.add(androidManifestFile);
    inputs.add(buildGradleFile);
    final Map<String, List<File>> results = <String, List<File>>{'inputs': inputs};
    results['outputs'] = await _setupComponentFiles(outputDir);
    return results;
  }

  // generates default build.gradle and AndroidManifest.xml for the deferred component.
  Future<List<File>> _setupComponentFiles(Directory outputDir) async {
    Template template;
    if (_templatesDir != null) {
      final Directory templateComponentDir = _templatesDir.childDirectory('module${env.fileSystem.path.separator}android${env.fileSystem.path.separator}deferred_component');
      template = Template(templateComponentDir, templateComponentDir, _templatesDir,
        fileSystem: env.fileSystem,
        templateManifest: null,
        logger: env.logger,
        templateRenderer: globals.templateRenderer,
      );
    } else {
      template = await Template.fromName('module${env.fileSystem.path.separator}android${env.fileSystem.path.separator}deferred_component',
        fileSystem: env.fileSystem,
        templateManifest: null,
        logger: env.logger,
        templateRenderer: globals.templateRenderer,
      );
    }
    final Map<String, dynamic> context = <String, dynamic>{
      'androidIdentifier': FlutterProject.current().manifest.androidPackage ?? 'com.example.${FlutterProject.current().manifest.appName}',
      'componentName': name,
    };

    template.render(outputDir, context);

    final List<File> generatedFiles = <File>[];

    final File tempBuildGradle = outputDir.childFile('build.gradle');
    if (!buildGradleFile.existsSync()) {
      generatedFiles.add(tempBuildGradle);
    } else {
      ErrorHandlingFileSystem.deleteIfExists(tempBuildGradle);
    }
    final File tempAndroidManifest = outputDir
      .childDirectory('src')
      .childDirectory('main')
      .childFile('AndroidManifest.xml');
    if (!androidManifestFile.existsSync()) {
      generatedFiles.add(tempAndroidManifest);
    } else {
      ErrorHandlingFileSystem.deleteIfExists(tempAndroidManifest);
    }
    return generatedFiles;
  }
}
