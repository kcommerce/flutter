// ignore_for_file: require_trailing_commas
// Copyright 2020, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:firebase_auth_platform_interface/src/method_channel/method_channel_firebase_auth.dart';
import 'package:firebase_auth_platform_interface/src/method_channel/method_channel_multi_factor.dart';
import 'package:firebase_auth_platform_interface/src/method_channel/utils/pigeon_helper.dart';
import 'package:firebase_auth_platform_interface/src/pigeon/messages.pigeon.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

/// Catches a [PlatformException] and converts it into a [FirebaseAuthException]
/// if it was intentionally caught on the native platform.
Never convertPlatformException(
  Object exception,
  StackTrace stackTrace, {
  bool fromPigeon = false,
}) {
  if (exception is! PlatformException) {
    Error.throwWithStackTrace(exception, stackTrace);
  }

  Error.throwWithStackTrace(
    platformExceptionToFirebaseAuthException(exception, fromPigeon: fromPigeon),
    stackTrace,
  );
}

/// Converts a [PlatformException] into a [FirebaseAuthException].
///
/// A [PlatformException] can only be converted to a [FirebaseAuthException] if
/// the `details` of the exception exist. Firebase returns specific codes and
/// messages which can be converted into user friendly exceptions.
// TODO(rousselGit): Should this return a FirebaseAuthException to avoid having to cast?
FirebaseException platformExceptionToFirebaseAuthException(
  PlatformException platformException, {
  bool fromPigeon = false,
}) {
  if (fromPigeon) {
    return FirebaseAuthException(
      code: platformException.code,
      // Remove leading classname from message
      message: platformException.message?.split(': ').last,
    );
  }

  Map<String, dynamic>? details = platformException.details != null
      ? Map<String, dynamic>.from(platformException.details)
      : null;

  String code = 'unknown';
  String? message = platformException.message;
  String? email;
  AuthCredential? credential;

  if (details != null) {
    code = details['code'] ?? code;
    if (code == 'second-factor-required') {
      return parseMultiFactorError(details);
    }

    message = details['message'] ?? message;

    final additionalData = details['additionalData'];

    if (additionalData != null) {
      if (additionalData['authCredential'] != null) {
        credential = AuthCredential(
          providerId: additionalData['authCredential']['providerId'],
          signInMethod: additionalData['authCredential']['signInMethod'],
          token: additionalData['authCredential']['token'],
        );
      }

      if (additionalData['email'] != null) {
        email = additionalData['email'];
      }
    }

    final customCode = _getCustomCode(additionalData, message);
    if (customCode != null) {
      code = customCode;
    }
  }
  return FirebaseAuthException(
    code: code,
    message: message,
    email: email,
    credential: credential,
  );
}

// Check for custom error codes that are not returned in the normal errors by Firebase SDKs
// The error code is only returned in a String on Android
String? _getCustomCode(Map? additionalData, String? message) {
  final listOfRecognizedCode = [
    // This code happens when using Enumerate Email protection
    'INVALID_LOGIN_CREDENTIALS',
    // This code happens when using using pre-auth functions
    'BLOCKING_FUNCTION_ERROR_RESPONSE',
  ];

  for (final recognizedCode in listOfRecognizedCode) {
    if (additionalData?['message'] == recognizedCode ||
        (message?.contains(recognizedCode) ?? false)) {
      return recognizedCode;
    }
  }

  return null;
}

FirebaseAuthMultiFactorExceptionPlatform parseMultiFactorError(
    Map<String, Object?> details) {
  final code = details['code'] as String?;
  final message = details['message'] as String?;
  final additionalData = details['additionalData'] as Map<Object?, Object?>?;

  if (additionalData == null) {
    throw FirebaseAuthException(
      code: "Can't parse multi factor error",
      message: message,
    );
  }

  final pigeonMultiFactorInfo =
      (additionalData['multiFactorHints'] as List<Object?>? ?? [])
          .whereNotNull()
          .map(
            PigeonMultiFactorInfo.decode,
          )
          .toList();

  final multiFactorInfo = multiFactorInfoPigeonToObject(
    pigeonMultiFactorInfo,
  );

  final auth = MethodChannelFirebaseAuth
      .methodChannelFirebaseAuthInstances[additionalData['appName']];

  if (auth == null) {
    throw FirebaseAuthException(
      code: code ?? 'Unknown',
      message: message,
    );
  }

  final sessionId = additionalData['multiFactorSessionId'] as String?;
  final resolverId = additionalData['multiFactorResolverId'] as String?;
  if (sessionId == null || resolverId == null) {
    throw FirebaseAuthException(
      code: "Can't parse multi factor error",
      message: message,
    );
  }
  final multiFactorResolver = MethodChannelMultiFactorResolver(
    multiFactorInfo,
    MultiFactorSession(sessionId),
    resolverId,
    auth,
  );

  return FirebaseAuthMultiFactorExceptionPlatform(
    code: code ?? 'Unknown',
    message: message,
    resolver: multiFactorResolver,
  );
}
