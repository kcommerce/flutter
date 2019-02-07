// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'keyboard_key.dart';
import 'keyboard_maps.dart';
import 'raw_keyboard.dart';

// Android sets the 0x80000000 bit on a character to indicate that it is a
// combining character, so we use this mask to remove that bit to make it a
// valid Unicode character again.
const int _kCombiningCharacterMask = 0x7fffffff;

/// Platform-specific key event data for Android.
///
/// This object contains information about key events obtained from Android's
/// `KeyEvent` interface.
///
/// See also:
///
///  * [RawKeyboard], which uses this interface to expose key data.
class RawKeyEventDataAndroid extends RawKeyEventData {
  /// Creates a key event data structure specific for Android.
  ///
  /// The [flags], [codePoint], [keyCode], [scanCode], and [metaState] arguments
  /// must not be null.
  const RawKeyEventDataAndroid({
    this.flags = 0,
    this.codePoint = 0,
    this.keyCode = 0,
    this.scanCode = 0,
    this.metaState = 0,
  }) : assert(flags != null),
       assert(codePoint != null),
       assert(keyCode != null),
       assert(scanCode != null),
       assert(metaState != null);

  /// The current set of additional flags for this event.
  ///
  /// Flags indicate things like repeat state, etc.
  ///
  /// See <https://developer.android.com/reference/android/view/KeyEvent.html#getFlags()>
  /// for more information.
  final int flags;

  /// The Unicode code point represented by the key event, if any.
  ///
  /// If there is no Unicode code point, this value is zero.
  ///
  /// Dead keys are represented as Unicode combining characters.
  ///
  /// See <https://developer.android.com/reference/android/view/KeyEvent.html#getUnicodeChar()>
  /// for more information.
  final int codePoint;

  /// The hardware key code corresponding to this key event.
  ///
  /// This is the physical key that was pressed, not the Unicode character.
  /// See [codePoint] for the Unicode character.
  ///
  /// See <https://developer.android.com/reference/android/view/KeyEvent.html#getKeyCode()>
  /// for more information.
  final int keyCode;

  /// The hardware scan code id corresponding to this key event.
  ///
  /// These values are not reliable and vary from device to device, so this
  /// information is mainly useful for debugging.
  ///
  /// See <https://developer.android.com/reference/android/view/KeyEvent.html#getScanCode()>
  /// for more information.
  final int scanCode;

  /// The modifiers that were present when the key event occurred.
  ///
  /// See <https://developer.android.com/reference/android/view/KeyEvent.html#getMetaState()>
  /// for the numerical values of the `metaState`. Many of these constants are
  /// also replicated as static constants in this class.
  ///
  /// See also:
  ///
  ///  * [modifiersPressed], which returns a Map of currently pressed modifiers
  ///    and their keyboard side.
  ///  * [isModifierPressed], to see if a specific modifier is pressed.
  ///  * [isControlPressed], to see if a CTRL key is pressed.
  ///  * [isShiftPressed], to see if a SHIFT key is pressed.
  ///  * [isAltPressed], to see if an ALT key is pressed.
  ///  * [isMetaPressed], to see if a META key is pressed.
  final int metaState;

  // Android only reports a single code point for the key label. We want to turn
  // off the Android combining character bit, since the Unicode code point will
  // indicate whether it is a combining characters anyhow.
  @override
  String get keyLabel => codePoint == 0 ? null : String.fromCharCode(_combinedCodePoint);

  // Handles the logic for removing Android's "combining character" flag on the
  // codePoint.
  int get _combinedCodePoint => codePoint & _kCombiningCharacterMask;

  @override
  PhysicalKeyboardKey get physicalKey => kAndroidToPhysicalKey[scanCode] ?? PhysicalKeyboardKey.none;

  @override
  LogicalKeyboardKey get logicalKey {
    // Look to see if the keyCode is a printable number pad key, so that a
    // difference between regular keys (e.g. "=") and the number pad version
    // (e.g. the "=" on the number pad) can be determined.
    final LogicalKeyboardKey numPadKey = kAndroidNumPadMap[keyCode];
    if (numPadKey != null) {
      return numPadKey;
    }

    // If it has a non-control-character label, then construct a new
    // Unicode-based key from it.
    if (keyLabel != null && keyLabel.isNotEmpty && !LogicalKeyboardKey.isControlCharacter(keyLabel)) {
      return LogicalKeyboardKey(
        LogicalKeyboardKey.unicodePlane | (_combinedCodePoint & LogicalKeyboardKey.valueMask),
        keyLabel: keyLabel,
        debugName: kReleaseMode ? null : 'Key $keyLabel',
      );
    }

    // Look to see if the keyCode is one we know about and have a mapping for.
    LogicalKeyboardKey newKey = kAndroidToLogicalKey[keyCode];
    if (newKey != null) {
      return newKey;
    }

    // This is a non-printable key that we don't know about, so we mint a new
    // code with the autogenerated bit set.
    const int androidKeyIdPlane = 0x00200000000;
    newKey ??= LogicalKeyboardKey(
      androidKeyIdPlane | keyCode | LogicalKeyboardKey.autogeneratedMask,
      debugName: kReleaseMode ? null : 'Unknown Android key code $keyCode',
    );
    return newKey;
  }

  bool _isLeftRightModifierPressed(KeyboardSide side, int anyMask, int leftMask, int rightMask) {
    if (metaState & anyMask == 0) {
      return false;
    }
    switch (side) {
      case KeyboardSide.any:
        return true;
      case KeyboardSide.all:
        return metaState & leftMask != 0 && metaState & rightMask != 0;
      case KeyboardSide.left:
        return metaState & leftMask != 0;
      case KeyboardSide.right:
        return metaState & rightMask != 0;
    }
    return false;
  }

  @override
  bool isModifierPressed(ModifierKey key, {KeyboardSide side = KeyboardSide.any}) {
    assert(side != null);
    switch (key) {
      case ModifierKey.controlModifier:
        return _isLeftRightModifierPressed(side, modifierControl, modifierLeftControl, modifierRightControl);
      case ModifierKey.shiftModifier:
        return _isLeftRightModifierPressed(side, modifierShift, modifierLeftShift, modifierRightShift);
      case ModifierKey.altModifier:
        return _isLeftRightModifierPressed(side, modifierAlt, modifierLeftAlt, modifierRightAlt);
      case ModifierKey.metaModifier:
        return _isLeftRightModifierPressed(side, modifierMeta, modifierLeftMeta, modifierRightMeta);
      case ModifierKey.capsLockModifier:
        return metaState & modifierCapsLock != 0;
      case ModifierKey.numLockModifier:
        return metaState & modifierNumLock != 0;
      case ModifierKey.scrollLockModifier:
        return metaState & modifierScrollLock != 0;
      case ModifierKey.functionModifier:
        return metaState & modifierFunction != 0;
      case ModifierKey.symbolModifier:
        return metaState & modifierSym != 0;
    }
    return false;
  }

  @override
  KeyboardSide getModifierSide(ModifierKey key) {
    KeyboardSide findSide(int leftMask, int rightMask) {
      final int combinedMask = leftMask | rightMask;
      final int combined = metaState & combinedMask;
      if (combined == leftMask) {
        return KeyboardSide.left;
      } else if (combined == rightMask) {
        return KeyboardSide.right;
      } else if (combined == combinedMask) {
        return KeyboardSide.all;
      }
      return null;
    }

    switch (key) {
      case ModifierKey.controlModifier:
        return findSide(modifierLeftControl, modifierRightControl);
      case ModifierKey.shiftModifier:
        return findSide(modifierLeftShift, modifierRightShift);
      case ModifierKey.altModifier:
        return findSide(modifierLeftAlt, modifierRightAlt);
      case ModifierKey.metaModifier:
        return findSide(modifierLeftMeta, modifierRightMeta);
      case ModifierKey.capsLockModifier:
      case ModifierKey.numLockModifier:
      case ModifierKey.scrollLockModifier:
      case ModifierKey.functionModifier:
      case ModifierKey.symbolModifier:
        return KeyboardSide.all;
    }

    assert(false, 'Not handling $key type properly.');
    return null;
  }

  // Modifier key masks.

  /// No modifier keys are pressed in the [metaState] field.
  ///
  /// Use this value if you need to decode the [metaState] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierNone = 0;

  /// This mask is used to check the [metaState] field to test whether one of
  /// the ALT modifier keys is pressed.
  ///
  /// Use this value if you need to decode the [metaState] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierAlt = 0x02;

  /// This mask is used to check the [metaState] field to test whether the left
  /// ALT modifier key is pressed.
  ///
  /// Use this value if you need to decode the [metaState] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierLeftAlt = 0x10;

  /// This mask is used to check the [metaState] field to test whether the right
  /// ALT modifier key is pressed.
  ///
  /// Use this value if you need to decode the [metaState] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierRightAlt = 0x20;

  /// This mask is used to check the [metaState] field to test whether one of
  /// the SHIFT modifier keys is pressed.
  ///
  /// Use this value if you need to decode the [metaState] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierShift = 0x01;

  /// This mask is used to check the [metaState] field to test whether the left
  /// SHIFT modifier key is pressed.
  ///
  /// Use this value if you need to decode the [metaState] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierLeftShift = 0x40;

  /// This mask is used to check the [metaState] field to test whether the right
  /// SHIFT modifier key is pressed.
  ///
  /// Use this value if you need to decode the [metaState] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierRightShift = 0x80;

  /// This mask is used to check the [metaState] field to test whether the SYM
  /// modifier key is pressed.
  ///
  /// Use this value if you need to decode the [metaState] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierSym = 0x04;

  /// This mask is used to check the [metaState] field to test whether the
  /// Function modifier key (Fn) is pressed.
  ///
  /// Use this value if you need to decode the [metaState] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierFunction = 0x08;

  /// This mask is used to check the [metaState] field to test whether one of
  /// the CTRL modifier keys is pressed.
  ///
  /// Use this value if you need to decode the [metaState] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierControl = 0x1000;

  /// This mask is used to check the [metaState] field to test whether the left
  /// CTRL modifier key is pressed.
  ///
  /// Use this value if you need to decode the [metaState] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierLeftControl = 0x2000;

  /// This mask is used to check the [metaState] field to test whether the right
  /// CTRL modifier key is pressed.
  ///
  /// Use this value if you need to decode the [metaState] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierRightControl = 0x4000;

  /// This mask is used to check the [metaState] field to test whether one of
  /// the META modifier keys is pressed.
  ///
  /// Use this value if you need to decode the [metaState] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierMeta = 0x10000;

  /// This mask is used to check the [metaState] field to test whether the left
  /// META modifier key is pressed.
  ///
  /// Use this value if you need to decode the [metaState] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierLeftMeta = 0x20000;

  /// This mask is used to check the [metaState] field to test whether the right
  /// META modifier key is pressed.
  ///
  /// Use this value if you need to decode the [metaState] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierRightMeta = 0x40000;

  /// This mask is used to check the [metaState] field to test whether the CAPS
  /// LOCK modifier key is on.
  ///
  /// Use this value if you need to decode the [metaState] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierCapsLock = 0x100000;

  /// This mask is used to check the [metaState] field to test whether the NUM
  /// LOCK modifier key is on.
  ///
  /// Use this value if you need to decode the [metaState] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierNumLock = 0x200000;

  /// This mask is used to check the [metaState] field to test whether the
  /// SCROLL LOCK modifier key is on.
  ///
  /// Use this value if you need to decode the [metaState] field yourself, but
  /// it's much easier to use [isModifierPressed] if you just want to know if
  /// a modifier is pressed.
  static const int modifierScrollLock = 0x400000;

  @override
  String toString() {
    return '$runtimeType(keyLabel: $keyLabel flags: $flags, codePoint: $codePoint, '
      'keyCode: $keyCode, scanCode: $scanCode, metaState: $metaState, '
      'modifiers down: $modifiersPressed)';
  }
}
