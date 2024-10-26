// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'enums.dart';
import 'globals.dart' show ConductorException, releaseCandidateBranchRegex;

/// Possible string formats that `flutter --version` can return.
enum VersionType {
  /// A stable flutter release.
  ///
  /// Example: '1.2.3'
  stable,

  /// A pre-stable flutter release.
  ///
  /// Example: '1.2.3-4.5.pre'
  development,

  /// A master channel flutter version.
  ///
  /// Example: '1.2.3-4.0.pre.10'
  ///
  /// The last number is the number of commits past the last tagged version.
  latest,

  /// A master channel flutter version from git describe.
  ///
  /// Example: '1.2.3-4.0.pre-10-gabc123'.
  /// Example: '1.2.3-10-gabc123'.
  gitDescribe,
}

final Map<VersionType, RegExp> versionPatterns = <VersionType, RegExp>{
  VersionType.stable: RegExp(r'^(\d+)\.(\d+)\.(\d+)$'),
  VersionType.development: RegExp(r'^(\d+)\.(\d+)\.(\d+)-(\d+)\.(\d+)\.pre$'),
  VersionType.latest: RegExp(r'^(\d+)\.(\d+)\.(\d+)-(\d+)\.(\d+)\.pre\.(\d+)$'),
  VersionType.gitDescribe: RegExp(r'^(\d+)\.(\d+)\.(\d+)-((\d+)\.(\d+)\.pre-)?(\d+)-g[a-f0-9]+$'),
};

class Version {
  Version({
    required this.x,
    required this.y,
    required this.z,
    this.m,
    this.n,
    this.commits,
    required this.type,
  }) {
    switch (type) {
      case VersionType.stable:
        assert(m == null);
        assert(n == null);
        assert(commits == null);
      case VersionType.development:
        assert(m != null);
        assert(n != null);
        assert(commits == null);
      case VersionType.latest:
        assert(m != null);
        assert(n != null);
        assert(commits != null);
      case VersionType.gitDescribe:
        assert(commits != null);
    }
  }

  /// Create a new [Version] from a version string.
  ///
  /// It is expected that [versionString] will be generated by
  /// `flutter --version` and match one of `stablePattern`, `developmentPattern`
  /// and `latestPattern`.
  factory Version.fromString(String versionString) {

    versionString = versionString.trim();
    // stable tag
    Match? match = versionPatterns[VersionType.stable]!.firstMatch(versionString);
    if (match != null) {
      // parse stable
      final List<int> parts = match
          .groups(<int>[1, 2, 3])
          .map((String? s) => int.parse(s!))
          .toList();
      return Version(
        x: parts[0],
        y: parts[1],
        z: parts[2],
        type: VersionType.stable,
      );
    }
    // development tag
    match = versionPatterns[VersionType.development]!.firstMatch(versionString);
    if (match != null) {
      // parse development
      final List<int> parts =
          match.groups(<int>[1, 2, 3, 4, 5]).map((String? s) => int.parse(s!)).toList();
      return Version(
        x: parts[0],
        y: parts[1],
        z: parts[2],
        m: parts[3],
        n: parts[4],
        type: VersionType.development,
      );
    }
    // latest tag
    match = versionPatterns[VersionType.latest]!.firstMatch(versionString);
    if (match != null) {
      // parse latest
      final List<int> parts = match.groups(
        <int>[1, 2, 3, 4, 5, 6],
      ).map(
        (String? s) => int.parse(s!),
      ).toList();
      return Version(
        x: parts[0],
        y: parts[1],
        z: parts[2],
        m: parts[3],
        n: parts[4],
        commits: parts[5],
        type: VersionType.latest,
      );
    }
    match = versionPatterns[VersionType.gitDescribe]!.firstMatch(versionString);
    if (match != null) {
      // parse latest
      final int x = int.parse(match.group(1)!);
      final int y = int.parse(match.group(2)!);
      final int z = int.parse(match.group(3)!);
      final int? m = int.tryParse(match.group(5) ?? '');
      final int? n = int.tryParse(match.group(6) ?? '');
      final int commits = int.parse(match.group(7)!);
      return Version(
        x: x,
        y: y,
        z: z,
        m: m,
        n: n,
        commits: commits,
        type: VersionType.gitDescribe,
      );
    }
    throw Exception('${versionString.trim()} cannot be parsed');
  }

  // Returns a new version with the given [increment] part incremented.
  // NOTE new version must be of same type as previousVersion.
  factory Version.increment(
    Version previousVersion,
    String increment, {
    VersionType? nextVersionType,
  }) {
    final int nextX = previousVersion.x;
    int nextY = previousVersion.y;
    int nextZ = previousVersion.z;
    int? nextM = previousVersion.m;
    int? nextN = previousVersion.n;
    nextVersionType ??= switch (previousVersion.type) {
      VersionType.stable => VersionType.stable,
      VersionType.latest || VersionType.gitDescribe || VersionType.development => VersionType.development,
    };

    switch (increment) {
      case 'x':
        // This was probably a mistake.
        throw Exception('Incrementing x is not supported by this tool.');
      case 'y':
        // Dev release following a beta release.
        nextY += 1;
        nextZ = 0;
        if (previousVersion.type != VersionType.stable) {
          nextM = 0;
          nextN = 0;
        }
      case 'z':
        // Hotfix to stable release.
        assert(previousVersion.type == VersionType.stable);
        nextZ += 1;
      case 'm':
        assert(false, "Do not increment 'm' via Version.increment, use instead Version.fromCandidateBranch()");
      case 'n':
        // Hotfix to internal roll.
        nextN = nextN! + 1;
      default:
        throw Exception('Unknown increment level $increment.');
    }
    return Version(
      x: nextX,
      y: nextY,
      z: nextZ,
      m: nextM,
      n: nextN,
      type: nextVersionType,
    );
  }

  factory Version.fromCandidateBranch(String branchName) {
    // Regular dev release.
    final RegExp pattern = RegExp(r'flutter-(\d+)\.(\d+)-candidate.(\d+)');
    final RegExpMatch? match = pattern.firstMatch(branchName);
    late final int x;
    late final int y;
    late final int m;
    try {
      x = int.parse(match!.group(1)!);
      y = int.parse(match.group(2)!);
      m = int.parse(match.group(3)!);
    } on Exception {
      throw ConductorException('branch named $branchName not recognized as a valid candidate branch');
    }

    return Version(
      type: VersionType.development,
      x: x,
      y: y,
      z: 0,
      m: m,
      n: 0,
    );
  }

  /// Major version.
  final int x;

  /// Zero-indexed count of beta releases after a major release.
  final int y;

  /// Number of hotfix releases after a stable release.
  ///
  /// For non-stable releases, this will be 0.
  final int z;

  /// Zero-indexed count of dev releases after a beta release.
  ///
  /// For stable releases, this will be null.
  final int? m;

  /// Number of hotfixes required to make a dev release.
  ///
  /// For stable releases, this will be null.
  final int? n;

  /// Number of commits past last tagged dev release.
  final int? commits;

  final VersionType type;

  /// Validate that the parsed version is valid.
  ///
  /// Will throw a [ConductorException] if the version is not possible given the
  /// [candidateBranch] and [incrementLetter].
  void ensureValid(String candidateBranch, ReleaseType releaseType) {
    final RegExpMatch? branchMatch = releaseCandidateBranchRegex.firstMatch(candidateBranch);
    if (branchMatch == null) {
      throw ConductorException(
        'Candidate branch $candidateBranch does not match the pattern '
        '${releaseCandidateBranchRegex.pattern}',
      );
    }

    // These groups are required in the pattern, so these match groups should
    // not be null
    final String branchX = branchMatch.group(1)!;
    if (x != int.tryParse(branchX)) {
      throw ConductorException(
        'Parsed version $this has a different x value than candidate '
        'branch $candidateBranch',
      );
    }
    final String branchY = branchMatch.group(2)!;
    if (y != int.tryParse(branchY)) {
      throw ConductorException(
        'Parsed version $this has a different y value than candidate '
        'branch $candidateBranch',
      );
    }

    // stable type versions don't have an m field set
    if (type != VersionType.stable && releaseType != ReleaseType.STABLE_HOTFIX && releaseType != ReleaseType.STABLE_INITIAL) {
      final String branchM = branchMatch.group(3)!;
      if (m != int.tryParse(branchM)) {
        throw ConductorException(
          'Parsed version $this has a different m value than candidate '
          'branch $candidateBranch with type $type',
        );
      }
    }
  }

  @override
  String toString() {
    return switch (type) {
      VersionType.stable      => '$x.$y.$z',
      VersionType.development => '$x.$y.$z-$m.$n.pre',
      VersionType.latest      => '$x.$y.$z-$m.$n.pre.$commits',
      VersionType.gitDescribe => '$x.$y.$z-$m.$n.pre.$commits',
    };
  }
}
