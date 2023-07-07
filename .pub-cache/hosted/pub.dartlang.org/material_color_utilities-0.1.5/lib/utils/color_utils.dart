// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// This file is automatically generated. Do not modify it.

import 'dart:math';
import 'package:material_color_utilities/utils/math_utils.dart';

/// Color science utilities.
///
/// Utility methods for color science constants and color space
/// conversions that aren't HCT or CAM16.
class ColorUtils {
  static final _SRGB_TO_XYZ = [
    [0.41233895, 0.35762064, 0.18051042],
    [0.2126, 0.7152, 0.0722],
    [0.01932141, 0.11916382, 0.95034478],
  ];

  static final _XYZ_TO_SRGB = [
    [
      3.2413774792388685,
      -1.5376652402851851,
      -0.49885366846268053,
    ],
    [
      -0.9691452513005321,
      1.8758853451067872,
      0.04156585616912061,
    ],
    [
      0.05562093689691305,
      -0.20395524564742123,
      1.0571799111220335,
    ],
  ];

  static final _WHITE_POINT_D65 = [95.047, 100.0, 108.883];

  /// Converts a color from RGB components to ARGB format.
  static int argbFromRgb(int red, int green, int blue) {
    return 255 << 24 | (red & 255) << 16 | (green & 255) << 8 | blue & 255;
  }

  /// Returns the alpha component of a color in ARGB format.
  static int alphaFromArgb(int argb) {
    return argb >> 24 & 255;
  }

  /// Converts a color from linear RGB components to ARGB format.
  static int argbFromLinrgb(List<double> linrgb) {
    final r = ColorUtils.delinearized(linrgb[0]);
    final g = ColorUtils.delinearized(linrgb[1]);
    final b = ColorUtils.delinearized(linrgb[2]);
    return ColorUtils.argbFromRgb(r, g, b);
  }

  /// Returns the red component of a color in ARGB format.
  static int redFromArgb(int argb) {
    return argb >> 16 & 255;
  }

  /// Returns the green component of a color in ARGB format.
  static int greenFromArgb(int argb) {
    return argb >> 8 & 255;
  }

  /// Returns the blue component of a color in ARGB format.
  static int blueFromArgb(int argb) {
    return argb & 255;
  }

  /// Returns whether a color in ARGB format is opaque.
  static bool isOpaque(int argb) {
    return alphaFromArgb(argb) >= 255;
  }

  /// Converts a color from ARGB to XYZ.
  static int argbFromXyz(double x, double y, double z) {
    final matrix = _XYZ_TO_SRGB;
    final linearR = matrix[0][0] * x + matrix[0][1] * y + matrix[0][2] * z;
    final linearG = matrix[1][0] * x + matrix[1][1] * y + matrix[1][2] * z;
    final linearB = matrix[2][0] * x + matrix[2][1] * y + matrix[2][2] * z;
    final r = delinearized(linearR);
    final g = delinearized(linearG);
    final b = delinearized(linearB);
    return argbFromRgb(r, g, b);
  }

  /// Converts a color from XYZ to ARGB.
  static List<double> xyzFromArgb(int argb) {
    final r = linearized(redFromArgb(argb));
    final g = linearized(greenFromArgb(argb));
    final b = linearized(blueFromArgb(argb));
    return MathUtils.matrixMultiply([r, g, b], _SRGB_TO_XYZ);
  }

  /// Converts a color represented in Lab color space into an ARGB
  /// integer.
  static int argbFromLab(double l, double a, double b) {
    final whitePoint = _WHITE_POINT_D65;
    final fy = (l + 16.0) / 116.0;
    final fx = a / 500.0 + fy;
    final fz = fy - b / 200.0;
    final xNormalized = _labInvf(fx);
    final yNormalized = _labInvf(fy);
    final zNormalized = _labInvf(fz);
    final x = xNormalized * whitePoint[0];
    final y = yNormalized * whitePoint[1];
    final z = zNormalized * whitePoint[2];
    return argbFromXyz(x, y, z);
  }

  /// Converts a color from ARGB representation to L*a*b*
  /// representation.
  ///
  /// [argb] the ARGB representation of a color
  /// Returns a Lab object representing the color
  static List<double> labFromArgb(int argb) {
    final linearR = linearized(redFromArgb(argb));
    final linearG = linearized(greenFromArgb(argb));
    final linearB = linearized(blueFromArgb(argb));
    final matrix = _SRGB_TO_XYZ;
    final x = matrix[0][0] * linearR +
        matrix[0][1] * linearG +
        matrix[0][2] * linearB;
    final y = matrix[1][0] * linearR +
        matrix[1][1] * linearG +
        matrix[1][2] * linearB;
    final z = matrix[2][0] * linearR +
        matrix[2][1] * linearG +
        matrix[2][2] * linearB;
    final whitePoint = _WHITE_POINT_D65;
    final xNormalized = x / whitePoint[0];
    final yNormalized = y / whitePoint[1];
    final zNormalized = z / whitePoint[2];
    final fx = _labF(xNormalized);
    final fy = _labF(yNormalized);
    final fz = _labF(zNormalized);
    final l = 116.0 * fy - 16;
    final a = 500.0 * (fx - fy);
    final b = 200.0 * (fy - fz);
    return [l, a, b];
  }

  /// Converts an L* value to an ARGB representation.
  ///
  /// [lstar] L* in L*a*b*
  /// Returns ARGB representation of grayscale color with lightness
  /// matching L*
  static int argbFromLstar(double lstar) {
    final fy = (lstar + 16.0) / 116.0;
    final fz = fy;
    final fx = fy;
    final kappa = 24389.0 / 27.0;
    final epsilon = 216.0 / 24389.0;
    final lExceedsEpsilonKappa = lstar > 8.0;
    final y = lExceedsEpsilonKappa ? fy * fy * fy : lstar / kappa;
    final cubeExceedEpsilon = fy * fy * fy > epsilon;
    final x = cubeExceedEpsilon ? fx * fx * fx : lstar / kappa;
    final z = cubeExceedEpsilon ? fz * fz * fz : lstar / kappa;
    final whitePoint = _WHITE_POINT_D65;
    return argbFromXyz(
      x * whitePoint[0],
      y * whitePoint[1],
      z * whitePoint[2],
    );
  }

  /// Computes the L* value of a color in ARGB representation.
  ///
  /// [argb] ARGB representation of a color
  /// Returns L*, from L*a*b*, coordinate of the color
  static double lstarFromArgb(int argb) {
    final y = xyzFromArgb(argb)[1] / 100.0;
    final e = 216.0 / 24389.0;
    if (y <= e) {
      return 24389.0 / 27.0 * y;
    } else {
      final yIntermediate = pow(y, 1.0 / 3.0).toDouble();
      return 116.0 * yIntermediate - 16.0;
    }
  }

  /// Converts an L* value to a Y value.
  ///
  /// L* in L*a*b* and Y in XYZ measure the same quantity, luminance.
  ///
  /// L* measures perceptual luminance, a linear scale. Y in XYZ
  /// measures relative luminance, a logarithmic scale.
  ///
  /// [lstar] L* in L*a*b*
  /// Returns Y in XYZ
  static double yFromLstar(double lstar) {
    final ke = 8.0;
    if (lstar > ke) {
      return pow((lstar + 16.0) / 116.0, 3.0).toDouble() * 100.0;
    } else {
      return lstar / (24389.0 / 27.0) * 100.0;
    }
  }

  /// Linearizes an RGB component.
  ///
  /// [rgbComponent] 0 <= rgb_component <= 255, represents R/G/B
  /// channel
  /// Returns 0.0 <= output <= 100.0, color channel converted to
  /// linear RGB space
  static double linearized(int rgbComponent) {
    final normalized = rgbComponent / 255.0;
    if (normalized <= 0.040449936) {
      return normalized / 12.92 * 100.0;
    } else {
      return pow((normalized + 0.055) / 1.055, 2.4).toDouble() * 100.0;
    }
  }

  /// Delinearizes an RGB component.
  ///
  /// [rgbComponent] 0.0 <= rgb_component <= 100.0, represents linear
  /// R/G/B channel
  /// Returns 0 <= output <= 255, color channel converted to regular
  /// RGB space
  static int delinearized(double rgbComponent) {
    final normalized = rgbComponent / 100.0;
    var delinearized = 0.0;
    if (normalized <= 0.0031308) {
      delinearized = normalized * 12.92;
    } else {
      delinearized = 1.055 * pow(normalized, 1.0 / 2.4).toDouble() - 0.055;
    }
    return MathUtils.clampInt(0, 255, (delinearized * 255.0).round());
  }

  /// Returns the standard white point; white on a sunny day.
  ///
  /// Returns The white point
  static List<double> whitePointD65() {
    return _WHITE_POINT_D65;
  }

  static double _labF(double t) {
    final e = 216.0 / 24389.0;
    final kappa = 24389.0 / 27.0;
    if (t > e) {
      return pow(t, 1.0 / 3.0).toDouble();
    } else {
      return (kappa * t + 16) / 116;
    }
  }

  static double _labInvf(double ft) {
    final e = 216.0 / 24389.0;
    final kappa = 24389.0 / 27.0;
    final ft3 = ft * ft * ft;
    if (ft3 > e) {
      return ft3;
    } else {
      return (116 * ft - 16) / kappa;
    }
  }
}
