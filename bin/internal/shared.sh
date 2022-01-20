#!/bin/sh
# Copyright 2014 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.


# ---------------------------------- NOTE ---------------------------------- #
#
# Please keep the logic in this file consistent with the logic in the
# `shared.bat` script in the same directory to ensure that Flutter & Dart continue
# to work across all platforms!
#
# -------------------------------------------------------------------------- #

set -e

# Needed because if it is set, cd may print the path it changed to.
unset CDPATH

pub_upgrade_with_retry () {
  _total_tries="10"
  _remaining_tries=$((_total_tries - 1))
  while [ "$_remaining_tries" -gt 0 ]; do
    (cd "$FLUTTER_TOOLS_DIR" && "$DART" __deprecated_pub upgrade "$VERBOSITY" --no-precompile) && break
    >&2 echo "Error: Unable to 'pub upgrade' flutter tool. Retrying in five seconds... ($_remaining_tries tries left)"
    _remaining_tries=$((_remaining_tries - 1))
    sleep 5
  done

  if [ "$_remaining_tries" = 0 ]; then
    >&2 echo "Command 'pub upgrade' still failed after $_total_tries tries, giving up."
    return 1
  fi
  return 0
}

# Trap function for removing any remaining lock file at exit.
_rmlock () {
  [ -n "$FLUTTER_UPGRADE_LOCK" ] && rm -rf "$FLUTTER_UPGRADE_LOCK"
}

# Determines which lock method to use, based on what is available on the system.
# Returns a non-zero value if the lock was not acquired, zero if acquired.
_lock () {
  if hash flock 2>/dev/null; then
    flock --nonblock --exclusive 7 2>/dev/null
  elif hash shlock 2>/dev/null; then
    shlock -f "$1" -p $$
  else
    mkdir "$1" 2>/dev/null
  fi
}

# Waits for an update lock to be acquired.
#
# To ensure that we don't simultaneously update Dart in multiple parallel
# instances, we try to obtain an exclusive lock on this file descriptor (and
# thus this script's source file) while we are updating Dart and compiling the
# script. To do this, we try to use the command line program "flock", which is
# available on many Unix-like platforms, in particular on most Linux
# distributions. You give it a file descriptor, and it locks the corresponding
# file, having inherited the file descriptor from the shell.
#
# Complicating matters, there are two major scenarios where this will not
# work.
#
# The first is if the platform doesn't have "flock", for example on macOS. There
# is not a direct equivalent, so on platforms that don't have flock, we fall
# back to using trying to use the shlock command, and if that doesn't exist,
# then we use mkdir as an atomic operation to create a lock directory. If mkdir
# is able to create the directory, then the lock is acquired. To determine if we
# have "flock" or "shlock" available, we use the "hash" shell built-in.
#
# The second complication is on network file shares. On NFS, to obtain an
# exclusive lock you need a file descriptor that is open for writing. Thus, we
# ignore errors from flock by redirecting all output to /dev/null, since users
# will typically not care about errors from flock and are more likely to be
# confused by them than helped. The "shlock" method doesn't work for network
# shares, since it is PID-based. The "mkdir" method does work over NFS
# implementations that support atomic directory creation (which is most of
# them). The "schlock" and "flock" commands are more reliable than the mkdir
# method, however, or we would use mkdir in all cases.
#
# The upgrade_flutter function calling _wait_for_lock is executed in a subshell
# with a redirect that pipes the source of this script into file descriptor 7.
# A flock lock is released when this subshell exits and file descriptor 7 is
# closed. The mkdir lock is released via an exit trap from the subshell that
# deletes the lock directory.
_wait_for_lock () {
  FLUTTER_UPGRADE_LOCK="$FLUTTER_ROOT/bin/cache/.upgrade_lock"
  while ! _lock "$FLUTTER_UPGRADE_LOCK"; do
    if [ -z "$_waiting_message_displayed" ]; then
      # Print with a return so that if the Dart code also prints this message
      # when it does its own lock, the message won't appear twice. Be sure that
      # the clearing printf below has the same number of space characters.
      printf "Waiting for another flutter command to release the startup lock...\r" >&2;
      _waiting_message_displayed="true"
    fi
    sleep .1;
  done
  if [ "$_waiting_message_displayed" = "true" ]; then
    # Clear the waiting message so it doesn't overlap any following text.
    printf "                                                                  \r" >&2;
  fi
  unset _waiting_message_displayed
  # If the lock file is acquired, make sure that it is removed on exit.
  trap _rmlock INT TERM EXIT
}

# This function is always run in a subshell. Running the function in a subshell
# is required to make sure any lock directory is cleaned up by the exit trap in
# _wait_for_lock.
upgrade_flutter () (
  mkdir -p "$FLUTTER_ROOT/bin/cache"

  _revision="$(cd "$FLUTTER_ROOT"; git rev-parse HEAD)"
  _compilekey="$_revision:$FLUTTER_TOOL_ARGS"

  # Invalidate cache if:
  #  * SNAPSHOT_PATH is not a file, or
  #  * STAMP_PATH is not a file, or
  #  * STAMP_PATH is an empty file, or
  #  * Contents of STAMP_PATH is not what we are going to compile, or
  #  * pubspec.yaml last modified after pubspec.lock
  if [ ! -f "$SNAPSHOT_PATH" ] || [ ! -s "$STAMP_PATH" ] || [ "$(cat "$STAMP_PATH")" != "$_compilekey" ] || [ -n "$(find "$FLUTTER_TOOLS_DIR/pubspec.yaml" -newer "$FLUTTER_TOOLS_DIR/pubspec.lock")" ]; then
    # Waits for the update lock to be acquired. Placing this check inside the
    # conditional allows the majority of flutter/dart installations to bypass
    # the lock entirely, but as a result this required a second verification that
    # the SDK is up to date.
    _wait_for_lock

    # A different shell process might have updated the tool/SDK.
    if [ -f "$SNAPSHOT_PATH" ] && [ -s "$STAMP_PATH" ] && [ "$(cat "$STAMP_PATH")" = "$_compilekey" ] && [ -n "$(find "$FLUTTER_TOOLS_DIR/pubspec.lock" -newer "$FLUTTER_TOOLS_DIR/pubspec.yaml")" ]; then
      exit $?
    fi

    # Fetch Dart...
    rm -f "$FLUTTER_ROOT/version"
    touch "$FLUTTER_ROOT/bin/cache/.dartignore"
    "$FLUTTER_ROOT/bin/internal/update_dart_sdk.sh"

    >&2 echo Building flutter tool...

    # Prepare packages...
    VERBOSITY="--verbosity=error"
    if [ "$CI" = "true" ] || [ "$BOT" = "true" ] || [ "$CONTINUOUS_INTEGRATION" = "true" ] || [ "$CHROME_HEADLESS" = "1" ]; then
      PUB_ENVIRONMENT="$PUB_ENVIRONMENT:flutter_bot"
      VERBOSITY="--verbosity=normal"
    fi
    export PUB_ENVIRONMENT="$PUB_ENVIRONMENT:flutter_install"
    if [ -d "$FLUTTER_ROOT/.pub-cache" ]; then
      export PUB_CACHE="${PUB_CACHE:-"$FLUTTER_ROOT/.pub-cache"}"
    fi
    pub_upgrade_with_retry

    # Compile...
    # FLUTTER_TOOL_ARGS aren't quoted below, because it is meant to be
    # considered as separate space-separated args.
    # shellcheck disable=SC2086
    "$DART" --verbosity=error --disable-dart-dev $FLUTTER_TOOL_ARGS --snapshot="$SNAPSHOT_PATH" --packages="$FLUTTER_TOOLS_DIR/.packages" --no-enable-mirrors "$SCRIPT_PATH"
    echo "$_compilekey" > "$STAMP_PATH"
  fi
  # The exit here is extraneous since the function is run in a subshell, but
  # this serves as documentation that running the function in a subshell is
  # required to make sure any lock directory created by mkdir is cleaned up.
  exit $?
)

# This function is intended to be executed by entrypoints (e.g. `//bin/flutter`
# and `//bin/dart`). PROG_NAME and BIN_DIR should already be set by those
# entrypoints.
shared_execute() {
  FLUTTER_ROOT="$(cd "${BIN_DIR}/.." ; pwd -P)"
  export FLUTTER_ROOT

  # If present, run the bootstrap script first
  BOOTSTRAP_PATH="$FLUTTER_ROOT/bin/internal/bootstrap.sh"
  if [ -f "$BOOTSTRAP_PATH" ]; then
    . "$BOOTSTRAP_PATH"
  fi

  FLUTTER_TOOLS_DIR="$FLUTTER_ROOT/packages/flutter_tools"
  SNAPSHOT_PATH="$FLUTTER_ROOT/bin/cache/flutter_tools.snapshot"
  STAMP_PATH="$FLUTTER_ROOT/bin/cache/flutter_tools.stamp"
  SCRIPT_PATH="$FLUTTER_TOOLS_DIR/bin/flutter_tools.dart"
  DART_SDK_PATH="$FLUTTER_ROOT/bin/cache/dart-sdk"

  DART="$DART_SDK_PATH/bin/dart"

  # If running over git-bash, overrides the default UNIX executables with win32
  # executables
  case "$(uname -s)" in
    MINGW*)
      DART="$DART.exe"
      ;;
  esac

  # Test if running as superuser – but don't warn if running within Docker or CI.
  if [ "$(id -u)" = "0" ] && [ ! -f /.dockerenv ] && [ "$CI" != "true" ] && [ "$BOT" != "true" ] && [ "$CONTINUOUS_INTEGRATION" != "true" ]; then
    >&2 echo "   Woah! You appear to be trying to run flutter as root."
    >&2 echo "   We strongly recommend running the flutter tool without superuser privileges."
    >&2 echo "  /"
    >&2 echo "📎"
  fi

  # Test if Git is available on the Host
  if ! hash git 2>/dev/null; then
    >&2 echo "Error: Unable to find git in your PATH."
    exit 1
  fi
  # Test if the flutter directory is a git clone (otherwise git rev-parse HEAD
  # would fail)
  if [ ! -e "$FLUTTER_ROOT/.git" ]; then
    >&2 echo "Error: The Flutter directory is not a clone of the GitHub project."
    >&2 echo "       The flutter tool requires Git in order to operate properly;"
    >&2 echo "       to install Flutter, see the instructions at:"
    >&2 echo "       https://flutter.dev/get-started"
    exit 1
  fi

  upgrade_flutter 7< "$PROG_NAME"

  BIN_NAME="$(basename "$PROG_NAME")"
  case "$BIN_NAME" in
    flutter*)
      # FLUTTER_TOOL_ARGS aren't quoted below, because it is meant to be
      # considered as separate space-separated args.
      # shellcheck disable=SC2086
      "$DART" --disable-dart-dev --packages="$FLUTTER_TOOLS_DIR/.packages" $FLUTTER_TOOL_ARGS "$SNAPSHOT_PATH" "$@"
      ;;
    dart*)
      "$DART" "$@"
      ;;
    *)
      >&2 echo "Error! Executable name $BIN_NAME not recognized!"
      exit 1
      ;;
  esac
}
