import 'dart:math';

class CalibrationCoefficients {
  final double a;
  final double b1;
  final double b2;
  final double b3;
  final double b4;
  final double b5;

  const CalibrationCoefficients({
    required this.a,
    required this.b1,
    required this.b2,
    required this.b3,
    required this.b4,
    required this.b5,
  });

  /// Default sample coefficients from Hamamatsu Inspection Sheet (Serial: 25M00109)
  factory CalibrationCoefficients.sample() {
    return const CalibrationCoefficients(
      a: 3.203084944e2,
      b1: 2.701214433e0,
      b2: -1.256913153e-3,
      b3: -6.720201165e-6,
      b4: 5.201013085e-9,
      b5: 1.121906608e-11,
    );
  }

  /// Calculates wavelength in nanometers for a given pixel index (0-based in code, 1-based in formula)
  double getWavelength(int pixelIndex0Based) {
    final double p = (pixelIndex0Based + 1).toDouble();
    return a +
        (b1 * p) +
        (b2 * pow(p, 2)) +
        (b3 * pow(p, 3)) +
        (b4 * pow(p, 4)) +
        (b5 * pow(p, 5));
  }

  Map<String, dynamic> toJson() => {
    'A': a,
    'B1': b1,
    'B2': b2,
    'B3': b3,
    'B4': b4,
    'B5': b5,
  };
}
