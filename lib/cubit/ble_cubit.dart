import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/calibration_coefficients.dart';
import 'ble_state.dart';

final Guid spectrometerServiceUuid = Guid(
  "0000FF00-0000-1000-8000-00805F9B34FB",
);
final Guid charControlUuid = Guid("0000FF04-0000-1000-8000-00805F9B34FB");

class BleCubit extends Cubit<BleState> {
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _controlCharacteristic;

  // Internal working buffer for 288 channels
  final List<int> _pixelBuffer = List.filled(288, 0);

  BleCubit() : super(BleState(coefficients: CalibrationCoefficients.sample())) {
    requestPermissions();
  }

  Future<void> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted) {
      emit(state.copyWith(status: BleStatus.initial));
    } else {
      emit(
        state.copyWith(
          status: BleStatus.error,
          errorMessage: "Bluetooth Permissions Denied",
        ),
      );
    }
  }

  void startScan() {
    emit(state.copyWith(status: BleStatus.scanning, scanResults: []));
    _scanSubscription?.cancel();
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      final filtered = results.where((r) {
        return r.device.platformName.contains('Pico-C12880MA') ||
            r.advertisementData.serviceUuids.contains(spectrometerServiceUuid);
      }).toList();
      emit(state.copyWith(scanResults: filtered));
    });

    FlutterBluePlus.startScan(
      withServices: [spectrometerServiceUuid],
      timeout: const Duration(seconds: 15),
    );
  }

  Future<void> connect(BluetoothDevice device) async {
    try {
      await FlutterBluePlus.stopScan();
      emit(
        state.copyWith(
          status: BleStatus.connecting,
          statusMessage: "Connecting...",
        ),
      );

      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;

      // Discover GATT services
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid == spectrometerServiceUuid) {
          for (var char in service.characteristics) {
            if (char.uuid == charControlUuid) {
              _controlCharacteristic = char;
            }

            if (char.properties.notify) {
              await char.setNotifyValue(true);
              char.onValueReceived.listen((data) {
                _handlePixelChunk(char.uuid.toString().toUpperCase(), data);
              });
            }
          }
        }
      }

      emit(
        state.copyWith(
          status: BleStatus.connected,
          statusMessage: "Spectrometer Connected",
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: BleStatus.error, errorMessage: e.toString()));
    }
  }

  void _handlePixelChunk(String uuid, List<int> rawBytes) {
    print("Received notify: $uuid | len: ${rawBytes.length}");
    if (rawBytes.length < 192) return; // 96 channels * 2 bytes

    final ByteData byteData = ByteData.sublistView(
      Uint8List.fromList(rawBytes),
    );
    int offset = 0;

    if (uuid.contains("FF01")) {
      offset = 0; // Pixels 0-95
    } else if (uuid.contains("FF02")) {
      offset = 96; // Pixels 96-191
    } else if (uuid.contains("FF03")) {
      offset = 192; // Pixels 192-287
    } else {
      return;
    }

    for (int i = 0; i < 96; i++) {
      _pixelBuffer[offset + i] = byteData.getUint16(i * 2, Endian.little);
    }

    // Emit updated copy of the buffer
    emit(state.copyWith(rawPixels: List<int>.from(_pixelBuffer)));
  }

  Future<void> toggleWhiteLed() async {
    if (_controlCharacteristic == null) return;
    final bool nextState = !state.whiteLedOn;
    try {
      // Command 0x01: Toggle LED (1=On, 0=Off)
      await _controlCharacteristic!.write([
        0x01,
        nextState ? 0x01 : 0x00,
      ], withoutResponse: true);
      emit(state.copyWith(whiteLedOn: nextState));
    } catch (e) {
      emit(state.copyWith(errorMessage: "Failed to set LED: $e"));
    }
  }

  void setIntegrationCycles(int cycles) {
    if (_controlCharacteristic == null) return;

    // Clamp to valid range (11 hardware minimum, 65535 max for uint16)
    final int clampedCycles = cycles.clamp(11, 65535);

    emit(state.copyWith(integrationCycles: clampedCycles));

    try {
      // Command 0x02: [ID] [LSB] [MSB]
      final int lsb = clampedCycles & 0xFF;
      final int msb = (clampedCycles >> 8) & 0xFF;

      _controlCharacteristic!.write([0x02, lsb, msb], withoutResponse: true);
    } catch (e) {
      emit(state.copyWith(errorMessage: "Failed to set integration time: $e"));
    }
  }

  void setCoefficients(CalibrationCoefficients newCoeffs) {
    emit(state.copyWith(coefficients: newCoeffs));
  }

  void saveDarkCalibration() {
    if (state.rawPixels.length == 288) {
      emit(
        state.copyWith(
          darkCalibration: List<int>.from(state.rawPixels),
          statusMessage: "Dark calibration saved",
        ),
      );
    }
  }

  void clearDarkCalibration() {
    emit(
      BleState(
        status: state.status,
        scanResults: state.scanResults,
        rawPixels: state.rawPixels,
        coefficients: state.coefficients,
        whiteLedOn: state.whiteLedOn,
        darkCalibration: null,
        whiteCalibration: state.whiteCalibration,
        showCalibratedData: false,
        statusMessage: "Dark reference cleared",
      ),
    );
  }

  void saveWhiteCalibration() {
    if (state.rawPixels.length == 288) {
      emit(
        state.copyWith(
          whiteCalibration: List<int>.from(state.rawPixels),
          statusMessage: "White calibration saved",
        ),
      );
    }
  }

  void clearWhiteCalibration() {
    emit(
      BleState(
        status: state.status,
        scanResults: state.scanResults,
        rawPixels: state.rawPixels,
        coefficients: state.coefficients,
        whiteLedOn: state.whiteLedOn,
        darkCalibration: state.darkCalibration,
        whiteCalibration: null,
        showCalibratedData: false,
        statusMessage: "White reference cleared",
      ),
    );
  }

  void toggleCalibratedView(bool value) {
    emit(state.copyWith(showCalibratedData: value));
  }

  Future<void> exportJson() async {
    try {
      final String jsonString = jsonEncode(state.toJson());
      final Uint8List bytes = utf8.encode(jsonString);

      final Uri? outputPath = await FilePicker.saveFile(
        dialogTitle: 'Export Spectral Run',
        fileName:
            'c12880ma_spectrum_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );

      if (outputPath != null) {
        emit(state.copyWith(statusMessage: "Saved successfully"));
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: "Export error: $e"));
    }
  }

  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _controlCharacteristic = null;
    emit(state.copyWith(status: BleStatus.initial, rawPixels: []));
  }

  @override
  Future<void> close() {
    _scanSubscription?.cancel();
    _connectedDevice?.disconnect();
    return super.close();
  }
}
