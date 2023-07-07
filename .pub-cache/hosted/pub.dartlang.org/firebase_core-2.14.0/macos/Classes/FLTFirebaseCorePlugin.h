// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <FlutterMacOS/FlutterMacOS.h>
#else
#import <Flutter/Flutter.h>
#endif

#import "FLTFirebasePlugin.h"
#import "messages.g.h"

@interface FLTFirebaseCorePlugin
    : FLTFirebasePlugin <FlutterPlugin, FLTFirebasePlugin, FirebaseCoreHostApi, FirebaseAppHostApi>
@end
