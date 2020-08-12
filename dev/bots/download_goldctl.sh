#!/usr/bin/env bash
# Copyright 2014 The Flutter Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git ./depot_tools
cd depot_tools
echo -e '# Ensure File\n$ServiceURL https://chrome-infra-packages.appspot.com\n\n# Skia Gold Client goldctl\nskia/tools/goldctl/${platform} bf0f1c34842dd8542f5072f4c4d5e1d2e53156379fc492af49ea9bf7f73c0be2' > ensure.txt
./cipd ensure -ensure-file ./ensure.txt -root .
