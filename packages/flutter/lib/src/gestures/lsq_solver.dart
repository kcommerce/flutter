// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import "dart:math" as math;
import "dart:typed_data";

class _Vector {
  _Vector(int size)
  : _offset = 0, _length = size, _elements = new Float64List(size);

  _Vector.fromValues(List<double> values)
  : _offset = 0, _length = values.length, _elements = values;

  _Vector.fromVOL(List<double> values, int offset, int length)
  : _offset = offset, _length = length, _elements = values;

  final int _offset;

  int get length => _length;
  final int _length;

  final List<double> _elements;

  double operator [](int i) => _elements[i + _offset];
  void operator []=(int i, double value) {
    _elements[i + _offset] = value;
  }

  double operator *(_Vector a) {
    double result = 0.0;
    for (int i = 0; i < _length; i += 1)
      result += this[i] * a[i];
    return result;
  }

  double norm() => math.sqrt(this * this);

  @override
  String toString() {
    String result = "";
    for (int i = 0; i < _length; i++) {
      if (i > 0)
        result += ", ";
        result += this[i].toString();
    }
    return result;
  }
}

class _Matrix {
  _Matrix(int rows, int cols)
  : _rows = rows,
    _columns = cols,
    _elements = new Float64List(rows * cols);

  final int _rows;
  final int _columns;
  final List<double> _elements;

  double get(int row, int col) => _elements[row * _columns + col];
  void set(int row, int col, double value) {
    _elements[row * _columns + col] = value;
  }

  _Vector getRow(int row) => new _Vector.fromVOL(
    _elements,
    row * _columns,
    _columns
  );

  @override
  String toString() {
    String result = "";
    for (int i = 0; i < _rows; i++) {
      if (i > 0)
        result += "; ";
      for (int j = 0; j < _columns; j++) {
        if (j > 0)
          result += ", ";
        result += get(i, j).toString();
      }
    }
    return result;
  }
}

/// An nth degree polynomial fit to a dataset.
class PolynomialFit {
  /// Creates a polynomial fit of the given degree.
  ///
  /// There are n + 1 coefficients in a fit of degree n.
  PolynomialFit(int degree) : coefficients = new Float64List(degree + 1);

  /// The polynomial coefficients of the fit.
  final List<double> coefficients;

  /// An indicator of the quality of the fit.
  ///
  /// Larger values indicate greater quality.
  double confidence;
}

/// Uses the least-squares algorithm to fit a polynomial to a set of data.
class LeastSquaresSolver {
  /// Creates a least-squares solver.
  ///
  /// The [x], [y], and [w] arguments must be non-null.
  LeastSquaresSolver(this.x, this.y, this.w) {
    assert(x.length == y.length);
    assert(y.length == w.length);
  }

  /// The x-coordinates of each data point.
  final List<double> x;

  /// The y-coordinates of each data point.
  final List<double> y;

  /// The weight to use for each data point.
  final List<double> w;

  /// Fits a polynomial of the given degree to the data points.
  PolynomialFit solve(int degree) {
    if (degree > x.length) // Not enough data to fit a curve.
      return null;

    PolynomialFit result = new PolynomialFit(degree);

    // Shorthands for the purpose of notation equivalence to original C++ code.
    final int m = x.length;
    final int n = degree + 1;

    // Expand the X vector to a matrix A, pre-multiplied by the weights.
    _Matrix a = new _Matrix(n, m);
    for (int h = 0; h < m; h += 1) {
      a.set(0, h, w[h]);
      for (int i = 1; i < n; i += 1)
        a.set(i, h, a.get(i - 1, h) * x[h]);
    }

    // Apply the Gram-Schmidt process to A to obtain its QR decomposition.

    // Orthonormal basis, column-major ordVectorer.
    _Matrix q = new _Matrix(n, m);
    // Upper triangular matrix, row-major order.
    _Matrix r = new _Matrix(n, n);
    for (int j = 0; j < n; j += 1) {
      for (int h = 0; h < m; h += 1)
        q.set(j, h, a.get(j, h));
      for (int i = 0; i < j; i += 1) {
        double dot = q.getRow(j) * q.getRow(i);
        for (int h = 0; h < m; h += 1)
          q.set(j, h, q.get(j, h) - dot * q.get(i, h));
      }

      double norm = q.getRow(j).norm();
      if (norm < 0.000001) {
        // Vectors are linearly dependent or zero so no solution.
        return null;
      }

      double inverseNorm = 1.0 / norm;
      for (int h = 0; h < m; h += 1)
        q.set(j, h, q.get(j, h) * inverseNorm);
      for (int i = 0; i < n; i += 1)
        r.set(j, i, i < j ? 0.0 : q.getRow(j) * a.getRow(i));
    }

    // Solve R B = Qt W Y to find B.  This is easy because R is upper triangular.
    // We just work from bottom-right to top-left calculating B's coefficients.
    _Vector wy = new _Vector(m);
    for (int h = 0; h < m; h += 1)
      wy[h] = y[h] * w[h];
    for (int i = n - 1; i >= 0; i -= 1) {
      result.coefficients[i] = q.getRow(i) * wy;
      for (int j = n - 1; j > i; j -= 1)
        result.coefficients[i] -= r.get(i, j) * result.coefficients[j];
      result.coefficients[i] /= r.get(i, i);
    }

    // Calculate the coefficient of determination (confidence) as:
    //   1 - (sumSquaredError / sumSquaredTotal)
    // ...where sumSquaredError is the residual sum of squares (variance of the
    // error), and sumSquaredTotal is the total sum of squares (variance of the
    // data) where each has been weighted.
    double yMean = 0.0;
    for (int h = 0; h < m; h += 1)
      yMean += y[h];
    yMean /= m;

    double sumSquaredError = 0.0;
    double sumSquaredTotal = 0.0;
    for (int h = 0; h < m; h += 1) {
      double term = 1.0;
      double err = y[h] - result.coefficients[0];
      for (int i = 1; i < n; i += 1) {
        term *= x[h];
        err -= term * result.coefficients[i];
      }
      sumSquaredError += w[h] * w[h] * err * err;
      final double v = y[h] - yMean;
      sumSquaredTotal += w[h] * w[h] * v * v;
    }

    result.confidence = sumSquaredTotal <= 0.000001 ? 1.0 :
                          1.0 - (sumSquaredError / sumSquaredTotal);

    return result;
  }

}
