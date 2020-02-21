// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/common.dart';

import '../base/file_system.dart';
import '../globals.dart' as globals;
import '../plugins.dart';
import '../project.dart';
import 'visual_studio_project.dart';

// Constants corresponding to specific reference types in a solution file.
// These values are defined by the .sln format.
const String _solutionTypeGuidFolder = '2150E333-8FDC-42A3-9474-1A3956D46DE8';
const String _solutionTypeGuidVcxproj = '8BC9CEB8-8B4A-11D0-8D11-00A0C91BC942';

// The GUID for the folder above, managed by this class. This is an arbitrary
// value that was randomly generated, but it should not be changed since that
// would cause issues for existing Flutter projects.
const String _flutterPluginSolutionFolderGuid = '5C2E738A-1DD3-445A-AAC8-EEB9648DD07C';
// The FlutterBuild project GUID. This is an arbitrary
// value that was randomly generated, but it should not be changed since that
// would cause issues for existing Flutter projects.
const String _flutterBuildProjectGuid = '6419BF13-6ECD-4CD2-9E85-E566A1F03F8F';

/// Extracts and stores the plugin name and vcxproj GUID for [plugin].
class _PluginProjectInfo {
  _PluginProjectInfo(Plugin plugin) {
    name = plugin.name;
    final File projectFile = globals.fs.directory(plugin.path).childDirectory('windows').childFile('plugin.vcxproj');
    guid = VisualStudioProject(projectFile).guid;
    if (guid == null) {
      throwToolExit('Unable to find a plugin.vcxproj for plugin "$name"');
    }
  }

  // The name of the plugin, which is also the name of the symlink folder.
  String name;

  // The GUID of the plugin's project.
  String guid;
}

/// Updates the solution file for [project] to have the project references and
/// dependencies to include [plugins], removing any previous plugins from the
/// solution.
Future<void> updatePluginsInSolution(WindowsProject project, List<Plugin> plugins) async {
  final String solutionContent = await project.solutionFile.readAsString();

  // Map of GUID to name for the current plugin list.
  final Map<String, String> currentPluginInfo = _getWindowsPluginNamesByGuid(plugins, project.pluginConfigKey);

  // Find any plugins referenced in the project that are no longer used, and
  // any that are new.
  //
  // While the simplest approach to updating the solution would be to remove all
  // entries associated with plugins, and then add all the current plugins in
  // one block, Visual Studio has its own (unknown, likely data-structure-hash
  // based) order that it will use each time it writes out the file due to any
  // solution-level changes made in the UI. To avoid thrashing, and resulting
  // confusion (e.g., in review diffs), this update attempts to instead preserve
  // the ordering that is already there, so that once Visual Studio has
  // reordered the plugins, that order will be stable.
  final Set<String> existingPlugins = _findPreviousPluginGuids(solutionContent);
  final Set<String> currentPlugins = currentPluginInfo.keys.toSet();
  final Set<String> removedPlugins = existingPlugins.difference(currentPlugins);
  final Set<String> addedPlugins = currentPlugins.difference(existingPlugins);

  final RegExp projectStartPattern = RegExp(r'^Project\("{' + _solutionTypeGuidVcxproj + r'}"\)\s*=\s*".*",\s*"(.*)",\s*"{([A-Fa-f0-9\-]*)}"\s*$');
  final RegExp pluginsFolderProjectStartPattern = RegExp(r'^Project\("{' + _solutionTypeGuidFolder + r'}"\)\s*=.*"{' + _flutterPluginSolutionFolderGuid + r'}"\s*$');
  final RegExp projectEndPattern = RegExp(r'^EndProject\s*$');
  final RegExp globalStartPattern = RegExp(r'^Global\s*$');
  final RegExp globalEndPattern = RegExp(r'^EndGlobal\s*$');
  final RegExp projectDependenciesStartPattern = RegExp(r'^\s*ProjectSection\(ProjectDependencies\)\s*=\s*postProject\s*$');
  final RegExp globalSectionProjectConfigurationStartPattern = RegExp(r'^\s*GlobalSection\(ProjectConfigurationPlatforms\)\s*=\s*postSolution\s*$');
  final RegExp globalSectionNestedProjectsStartPattern = RegExp(r'^\s*GlobalSection\(NestedProjects\)\s*=\s*preSolution\s*$');

  final StringBuffer newSolutionContent = StringBuffer();
  final Iterator<String> lineIterator = solutionContent.split('\n').iterator;
  bool foundFlutterPluginsFolder = false;
  bool foundNestedProjectsSection = false;
  bool foundRunnerProject = false;
  while (lineIterator.moveNext()) {
    final Match projectStartMatch = projectStartPattern.firstMatch(lineIterator.current);
    if (projectStartMatch != null) {
      final String guid = projectStartMatch.group(2);
      if (currentPlugins.contains(guid)) {
        // Write an up-to-date version at this location (in case, e.g., the name
        // has changed).
        _writePluginProjectEntry(guid, currentPluginInfo[guid], newSolutionContent);
        // Drop the old copy.
        _skipUntil(lineIterator, projectEndPattern);
        continue;
      } else if (removedPlugins.contains(guid)) {
        // Drop the stale plugin project.
        _skipUntil(lineIterator, projectEndPattern);
        continue;
      } else if (projectStartMatch.group(1) == project.vcprojFile.basename) {
        foundRunnerProject = true;
        // Update the Runner project's dependencies on the plugins.
        // Skip to the dependencies section, or if there isn't one the end of
        // the project.
        while (!projectDependenciesStartPattern.hasMatch(lineIterator.current) &&
            !projectEndPattern.hasMatch(lineIterator.current)) {
          newSolutionContent.writeln(lineIterator.current);
          lineIterator.moveNext();
        }
        // Add/update the dependencies section.
        if (projectDependenciesStartPattern.hasMatch(lineIterator.current)) {
          newSolutionContent.writeln(lineIterator.current);
          _processSectionPluginReferences(removedPlugins, addedPlugins, lineIterator, _writeProjectDependency, newSolutionContent);
        } else {
          _writeDependenciesSection(currentPlugins, newSolutionContent);
        }
      }
    }

    if (pluginsFolderProjectStartPattern.hasMatch(lineIterator.current)) {
        foundFlutterPluginsFolder = true;
    }

    if (globalStartPattern.hasMatch(lineIterator.current)) {
      // The Global section is the end of the project list. Add any new plugins
      // here, since the location VS will use is unknown. They will likely be
      // reordered the next time VS writes the file.
      for (final String guid in addedPlugins) {
        _writePluginProjectEntry(guid, currentPluginInfo[guid], newSolutionContent);
      }
      // Also add the plugins folder if there wasn't already one.
      if (!foundFlutterPluginsFolder) {
        _writePluginFolderProjectEntry(newSolutionContent);
      }
    }

    // Update the ProjectConfiguration section once it is reached.
    if (globalSectionProjectConfigurationStartPattern.hasMatch(lineIterator.current)) {
      newSolutionContent.writeln(lineIterator.current);
      _processSectionPluginReferences(removedPlugins, addedPlugins, lineIterator, _writePluginConfigurationEntries, newSolutionContent);
    }

    // Update the NestedProjects section once it is reached.
    if (globalSectionNestedProjectsStartPattern.hasMatch(lineIterator.current)) {
      newSolutionContent.writeln(lineIterator.current);
      _processSectionPluginReferences(removedPlugins, addedPlugins, lineIterator, _writePluginNestingEntry, newSolutionContent);
      foundNestedProjectsSection = true;
    }

    // If there wasn't a NestedProjects global section, add one at the end.
    if (!foundNestedProjectsSection && globalEndPattern.hasMatch(lineIterator.current)) {
      newSolutionContent.writeln('\tGlobalSection(NestedProjects) = preSolution\r');
      for (final String guid in currentPlugins) {
        _writePluginNestingEntry(guid, newSolutionContent);
      }
      newSolutionContent.writeln('\tEndGlobalSection\r');
    }

    // Re-output anything that hasn't been explicitly skipped above.
    newSolutionContent.writeln(lineIterator.current);
  }

  if (!foundRunnerProject) {
    throwToolExit(
        'Could not add plugins to Windows project:\n'
        'Unable to find a "${project.vcprojFile.basename}" project in ${project.solutionFile.path}');
  }

  await project.solutionFile.writeAsString(newSolutionContent.toString().trimRight());
}

/// Advances [iterator] it reaches an element that matches [pattern].
///
/// Note that the current element at the time of calling is *not* checked.
void _skipUntil(Iterator<String> iterator, RegExp pattern) {
  while (iterator.moveNext()) {
    if (pattern.hasMatch(iterator.current)) {
      return;
    }
  }
}

/// Writes the main project entry for the plugin with the given [guid] and
/// [name].
void _writePluginProjectEntry(String guid, String name, StringBuffer output) {
  output.write('''
Project("{$_solutionTypeGuidVcxproj}") = "$name", "Flutter\\ephemeral\\.plugin_symlinks\\$name\\windows\\plugin.vcxproj", "{$guid}"\r
\tProjectSection(ProjectDependencies) = postProject\r
\t\t{$_flutterBuildProjectGuid} = {$_flutterBuildProjectGuid}\r
\tEndProjectSection\r
EndProject\r
''');
}

/// Writes the main project entry for the Flutter Plugins solution folder.
void _writePluginFolderProjectEntry(StringBuffer output) {
  const String folderName = 'Flutter Plugins';
  output.write('''
Project("{$_solutionTypeGuidFolder}") = "$folderName", "$folderName", "{$_flutterPluginSolutionFolderGuid}"\r
EndProject\r
''');
}

/// Writes a project dependencies section, depending on all the GUIDs in
/// [dependencies].
void _writeDependenciesSection(Iterable<String> dependencies, StringBuffer output) {
	output.writeln('ProjectSection(ProjectDependencies) = postProject\r');
  for (final String guid in dependencies) {
    _writeProjectDependency(guid, output);
  }
	output.writeln('EndProjectSection\r');
}

/// Returns the GUIDs of all the Flutter plugin projects in the given solution.
Set<String> _findPreviousPluginGuids(String solutionContent) {
  // Find the plugin folder's known GUID in ProjectDependencies lines.
  // Each line in that section has the form:
  //   {project GUID} = {solution folder GUID}
  final RegExp pluginFolderChildrenPattern = RegExp(
      r'^\s*{([A-Fa-f0-9\-]*)}\s*=\s*{' + _flutterPluginSolutionFolderGuid + r'}\s*$',
      multiLine: true,
  );
  return pluginFolderChildrenPattern
      .allMatches(solutionContent)
      .map((Match match) => match.group(1)).toSet();
}

/// Returns a mapping of plugin project GUID to name for all the Windows plugins
/// in [plugins].
Map<String, String> _getWindowsPluginNamesByGuid(List<Plugin> plugins, String platformKey) {
  final Map<String, String> currentPluginInfo = <String, String>{};
  for (final Plugin plugin in plugins) {
    if (plugin.platforms.containsKey(platformKey)) {
      final _PluginProjectInfo info = _PluginProjectInfo(plugin);
      if (currentPluginInfo.containsKey(info.guid)) {
        throwToolExit('The plugins "${currentPluginInfo[info.guid]}" and "${info.name}" '
            'have the same ProjectGuid, which prevents them from being used together.\n\n'
            'Please contact the plugin authors to resolve this, and/or remove one of the '
            'plugins from your project.');
      }
      currentPluginInfo[info.guid] = info.name;
    }
  }
  return currentPluginInfo;
}

/// Walks a GlobalSection or ProjectSection, removing entries related to removed
/// plugins and adding entries for new plugins at the end using
/// [newEntryWriter], which takes the guid of the plugin to write entries for.
///
/// The caller is responsible for printing the section start line, which should
/// be [lineIterator.current] when this is called, and the section end line,
/// which will be [lineIterator.current] on return.
void _processSectionPluginReferences(
    Set<String> removedPlugins,
    Set<String> addedPlugins,
    Iterator<String> lineIterator,
    Function(String, StringBuffer) newEntryWriter,
    StringBuffer output,
) {
  // Extracts the guid of the project that a line refers to. Currently all
  // sections this function is used for start with "{project guid}", even though
  // the rest of the line varies by section, so the pattern can currently be
  // shared rather than parameterized.
  final RegExp entryPattern = RegExp(r'^\s*{([A-Fa-f0-9\-]*)}');
  final RegExp sectionEndPattern = RegExp(r'^\s*End\w*Section\s*$');
  while (lineIterator.moveNext()) {
    if (sectionEndPattern.hasMatch(lineIterator.current)) {
      // The end of the section; add entries for new plugins, then exit.
      for (final String guid in addedPlugins) {
        newEntryWriter(guid, output);
      }
      return;
    }
    // Otherwise it's the sectino body. Drop any lines associated with old
    // plugins, but pass everything else through as output.
    final Match entryMatch = entryPattern.firstMatch(lineIterator.current);
    if (entryMatch != null && removedPlugins.contains(entryMatch.group(1))) {
      continue;
    }
    output.writeln(lineIterator.current);
  }
}

/// Writes all the configuration entries for the plugin project with the given
/// [guid].
///
/// Should be called within the context of writing
/// GlobalSection(ProjectConfigurationPlatforms).
void _writePluginConfigurationEntries(String guid, StringBuffer output) {
  final List<String> configurations = <String>['Debug', 'Profile', 'Release'];
  final List<String> entryTypes = <String>['ActiveCfg', 'Build.0'];
  for (final String configuration in configurations) {
    for (final String entryType in entryTypes) {
      output.writeln('\t\t{$guid}.$configuration|x64.$entryType = $configuration|x64\r');
    }
  }
}

/// Writes the entries to nest the plugin projects with the given [guid] under
/// the Flutter Plugins solution folder.
///
/// Should be called within the context of writing
/// GlobalSection(NestedProjects).
void _writePluginNestingEntry(String guid, StringBuffer output) {
  output.writeln('\t\t{$guid} = {$_flutterPluginSolutionFolderGuid}\r');
}

/// Writes the entrie to make a project depend on another project with the
/// given [guid].
///
/// Should be called within the context of writing
/// ProjectSection(ProjectDependencies).
void _writeProjectDependency(String guid, StringBuffer output) {
  output.writeln('\t\t{$guid} = {$guid}\r');
}
