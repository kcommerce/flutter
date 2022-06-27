// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io' as io;

import 'package:process/process.dart';

import 'git.dart';
import 'globals.dart';
import 'repository.dart';

/// A service for rolling the SDK's pub packages to latest and open a PR upstream.
class PackageAutoroller {
  PackageAutoroller({
    required this.githubClient,
    required this.token,
    required this.framework,
    required this.orgName,
    required this.processManager,
  }) {
    if (token.trim().isEmpty) {
      throw Exception('empty token!');
    }
    if (githubClient.trim().isEmpty) {
      throw Exception('Must provide path to GitHub client!');
    }
    if (orgName.trim().isEmpty) {
      throw Exception('Must provide an orgName!');
    }
  }

  final FrameworkRepository framework;
  final ProcessManager processManager;

  /// Path to GitHub CLI client.
  final String githubClient;

  /// GitHub API access token.
  final String token;

  static const String hostname = 'github.com';

  static const String prBody = '''
This PR was generated by `flutter update-packages --force-upgrade`.
''';

  /// Name of the feature branch to be opened on against the mirror repo.
  ///
  /// We never re-use a previous branch, so the branch name ends in an index
  /// number, which gets incremented for each roll.
  late final Future<String> featureBranchName = (() async {
    final List<String> remoteBranches = await framework.listRemoteBranches(framework.mirrorRemote!.name);

    int x = 1;
    String name(int index) => 'packages-autoroller-branch-$index';

    while (remoteBranches.contains(name(x))) {
      x += 1;
    }

    return name(x);
  })();

  /// Name of the GitHub organization to push the feature branch to.
  final String orgName;

  Future<void> roll() async {
    try {
      await authLogin();
      await updatePackages();
      await pushBranch();
      await createPr(
        repository: await framework.checkoutDirectory,
      );
      await authLogout();
    } on Exception catch (exception) {
      _filterException(exception);
    }
  }

  // Ensure we don't leak the GitHub token in exception messages
  Never _filterException(Exception exception) {
    String message = exception.toString();
    message = message.replaceAll(token, '[GitHub TOKEN]');
    throw Exception('${exception.runtimeType}: $message');
  }

  Future<void> updatePackages({
    bool verbose = true,
    String author = 'flutter-packages-autoroller <flutter-packages-autoroller@google.com>'
  }) async {
    await framework.newBranch(await featureBranchName);
    final io.Process flutterProcess = await framework.streamFlutter(<String>[
      if (verbose) '--verbose',
      'update-packages',
      '--force-upgrade',
    ]);
    final int exitCode = await flutterProcess.exitCode;
    if (exitCode != 0) {
      throw ConductorException('Failed to update packages with exit code $exitCode');
    }
    await framework.commit(
      'roll packages',
      addFirst: true,
      author: author,
    );
  }

  Future<void> pushBranch() async {
    final String projectName = framework.mirrorRemote!.url.split(r'/').last;
    // Encode the token into the remote URL for authentication to work
    final String remote = 'https://$token@$hostname/$orgName/$projectName';
    await framework.pushRef(
      fromRef: await featureBranchName,
      toRef: await featureBranchName,
      remote: remote,
    );
  }

  Future<void> authLogout() {
    return cli(
      <String>['auth', 'logout', '--hostname', hostname],
      allowFailure: true,
    );
  }

  Future<void> authLogin() {
    return cli(
      <String>[
        'auth',
        'login',
        '--hostname',
        hostname,
        '--git-protocol',
        'https',
        '--with-token',
      ],
      stdin: '$token\n',
    );
  }

  /// Create a pull request on GitHub.
  ///
  /// Depends on the gh cli tool.
  Future<void> createPr({
    required io.Directory repository,
    String title = 'Roll pub packages',
    String body = 'This PR was generated by `flutter update-packages --force-upgrade`.',
    String base = FrameworkRepository.defaultBranch,
    bool draft = false,
  }) async {
    // We will wrap title and body in double quotes before delegating to gh
    // binary
    await cli(
      <String>[
        'pr',
        'create',
        '--title',
        title.trim(),
        '--body',
        body.trim(),
        '--head',
        '$orgName:${await featureBranchName}',
        '--base',
        base,
        if (draft)
          '--draft',
      ],
      workingDirectory: repository.path,
    );
  }

  Future<void> help([List<String>? args]) {
    return cli(<String>[
      'help',
      ...?args,
    ]);
  }

  Future<void> cli(
    List<String> args, {
    bool allowFailure = false,
    String? stdin,
    String? workingDirectory,
  }) async {
    print('Executing "$githubClient ${args.join(' ')}" in $workingDirectory');
    final io.Process process = await processManager.start(
      <String>[githubClient, ...args],
      workingDirectory: workingDirectory,
      environment: <String, String>{},
    );
    final List<String> stderrStrings = <String>[];
    final List<String> stdoutStrings = <String>[];
    final Future<void> stdoutFuture = process.stdout
        .transform(utf8.decoder)
        .forEach(stdoutStrings.add);
    final Future<void> stderrFuture = process.stderr
        .transform(utf8.decoder)
        .forEach(stderrStrings.add);
    if (stdin != null) {
      process.stdin.write(stdin);
      await process.stdin.flush();
      await process.stdin.close();
    }
    final int exitCode = await process.exitCode;
    await Future.wait(<Future<Object?>>[
      stdoutFuture,
      stderrFuture,
    ]);
    final String stderr = stderrStrings.join();
    final String stdout = stdoutStrings.join();
    if (!allowFailure && exitCode != 0) {
      throw GitException(
        '$stderr\n$stdout',
        args,
      );
    }
    print(stdout);
  }
}
