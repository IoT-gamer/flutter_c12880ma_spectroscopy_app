import 'package:equatable/equatable.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/calibration_coefficients.dart';

enum BleStatus { initial, scanning, connecting, connected, disconnected, error }

class BleState extends Equatable {
  final BleStatus status;
  final List<ScanResult> scanResults;
  final List<int> rawPixels; // 288 raw uint16 ADC values
  final CalibrationCoefficients coefficients;
  final bool whiteLedOn;
  final int integrationCycles;
  final List<int>? darkCalibration;
  final List<int>? whiteCalibration;
  final bool showCalibratedData;
  final String statusMessage;
  final String? errorMessage;

  const BleState({
    this.status = BleStatus.initial,
    this.scanResults = const [],
    this.rawPixels = const [],
    required this.coefficients,
    this.whiteLedOn = false,
    this.integrationCycles = 10,
    this.darkCalibration,
    this.whiteCalibration,
    this.showCalibratedData = false,
    this.statusMessage = "",
    this.errorMessage,
  });

  BleState copyWith({
    BleStatus? status,
    List<ScanResult>? scanResults,
    List<int>? rawPixels,
    CalibrationCoefficients? coefficients,
    bool? whiteLedOn,
    int? integrationCycles,
    List<int>? darkCalibration,
    List<int>? whiteCalibration,
    bool? showCalibratedData,
    String? statusMessage,
    String? errorMessage,
  }) {
    return BleState(
      status: status ?? this.status,
      scanResults: scanResults ?? this.scanResults,
      rawPixels: rawPixels ?? this.rawPixels,
      coefficients: coefficients ?? this.coefficients,
      whiteLedOn: whiteLedOn ?? this.whiteLedOn,
      integrationCycles: integrationCycles ?? this.integrationCycles,
      darkCalibration: darkCalibration ?? this.darkCalibration,
      whiteCalibration: whiteCalibration ?? this.whiteCalibration,
      showCalibratedData: showCalibratedData ?? this.showCalibratedData,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Calculates real-time reflectance %: ((raw - dark) / (white - dark)) * 100
  List<double> get processedData {
    if (rawPixels.isEmpty) return [];

    if (showCalibratedData &&
        darkCalibration != null &&
        whiteCalibration != null &&
        darkCalibration!.length == 288 &&
        whiteCalibration!.length == 288) {
      return List.generate(288, (i) {
        final double raw = rawPixels[i].toDouble();
        final double dark = darkCalibration![i].toDouble();
        final double white = whiteCalibration![i].toDouble();
        final double denom = white - dark;

        if (denom <= 0) return 0.0;
        final double reflectance = ((raw - dark) / denom) * 100.0;
        return reflectance.clamp(0.0, 150.0);
      });
    }

    return rawPixels.map((p) => p.toDouble()).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'coefficients': coefficients.toJson(),
      'raw_adc_data': rawPixels,
      'calibrated_reflectance': showCalibratedData ? processedData : null,
      'dark_reference': darkCalibration,
      'white_reference': whiteCalibration,
      'led_status': {'white_led': whiteLedOn},
    };
  }

  @override
  List<Object?> get props => [
    status,
    scanResults,
    rawPixels,
    coefficients,
    whiteLedOn,
    integrationCycles,
    darkCalibration,
    whiteCalibration,
    showCalibratedData,
    statusMessage,
    errorMessage,
  ];
}
