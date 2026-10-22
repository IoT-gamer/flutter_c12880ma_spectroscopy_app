import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../cubit/ble_cubit.dart';
import '../cubit/ble_state.dart';
import '../models/calibration_coefficients.dart';
import '../widgets/spectral_line_chart.dart';

class SpectrometerScreen extends StatelessWidget {
  const SpectrometerScreen({super.key});

  void _showCoefficientsDialog(BuildContext context) {
    final cubit = context.read<BleCubit>();
    final current = cubit.state.coefficients;

    final aCtrl = TextEditingController(text: current.a.toString());
    final b1Ctrl = TextEditingController(text: current.b1.toString());
    final b2Ctrl = TextEditingController(text: current.b2.toString());
    final b3Ctrl = TextEditingController(text: current.b3.toString());
    final b4Ctrl = TextEditingController(text: current.b4.toString());
    final b5Ctrl = TextEditingController(text: current.b5.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Calibration Coefficients"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(aCtrl, "A (Intercept)"),
              _field(b1Ctrl, "B1"),
              _field(b2Ctrl, "B2"),
              _field(b3Ctrl, "B3"),
              _field(b4Ctrl, "B4"),
              _field(b5Ctrl, "B5"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final newCoeffs = CalibrationCoefficients(
                a: double.tryParse(aCtrl.text) ?? current.a,
                b1: double.tryParse(b1Ctrl.text) ?? current.b1,
                b2: double.tryParse(b2Ctrl.text) ?? current.b2,
                b3: double.tryParse(b3Ctrl.text) ?? current.b3,
                b4: double.tryParse(b4Ctrl.text) ?? current.b4,
                b5: double.tryParse(b5Ctrl.text) ?? current.b5,
              );
              cubit.setCoefficients(newCoeffs);
              Navigator.pop(ctx);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label, isDense: true),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pico C12880MA Spectrometer"),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: "Edit Coefficients",
            onPressed: () => _showCoefficientsDialog(context),
          ),
          BlocBuilder<BleCubit, BleState>(
            builder: (context, state) {
              return IconButton(
                icon: Icon(
                  state.status == BleStatus.scanning
                      ? Icons.stop
                      : Icons.search,
                ),
                onPressed: () => context.read<BleCubit>().startScan(),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<BleCubit, BleState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
        },
        builder: (context, state) {
          switch (state.status) {
            case BleStatus.initial:
              return const Center(
                child: Text("Tap search to find Pico-C12880MA"),
              );
            case BleStatus.scanning:
              return _buildScanList(state.scanResults, context);
            case BleStatus.connecting:
              return const Center(child: CircularProgressIndicator());
            case BleStatus.connected:
              return _buildDashboard(context, state);
            case BleStatus.disconnected:
              return const Center(
                child: Text("Disconnected. Tap search to reconnect."),
              );
            case BleStatus.error:
              return Center(child: Text("Error: ${state.errorMessage}"));
          }
        },
      ),
    );
  }

  Widget _buildScanList(List<ScanResult> results, BuildContext context) {
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final dev = results[index].device;
        return ListTile(
          title: Text(
            dev.platformName.isEmpty
                ? "Unknown Spectrometer"
                : dev.platformName,
          ),
          subtitle: Text(dev.remoteId.str),
          trailing: ElevatedButton(
            onPressed: () => context.read<BleCubit>().connect(dev),
            child: const Text("Connect"),
          ),
        );
      },
    );
  }

  Widget _buildDashboard(BuildContext context, BleState state) {
    final cubit = context.read<BleCubit>();
    final bool canCalibrate =
        state.darkCalibration != null && state.whiteCalibration != null;

    return SingleChildScrollView(
      child: Column(
        children: [
          const SpectralLineChart(),
          SwitchListTile(
            title: const Text("View Calibrated Reflectance (%)"),
            subtitle: const Text(
              "Requires both Dark and White reference captures",
            ),
            value: state.showCalibratedData,
            onChanged: canCalibrate
                ? (val) => cubit.toggleCalibratedView(val)
                : null,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Integration Time (${state.integrationCycles} ms)",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: state.integrationCycles.toDouble(),
                  min: 1, // 1 ms (Minimum timer resolution)
                  max: 500, // 500 ms (Half-second exposure)
                  divisions: 499,
                  onChanged: (val) => cubit.setIntegrationCycles(val.toInt()),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text("White Light Illumination"),
            trailing: ElevatedButton.icon(
              icon: Icon(
                Icons.lightbulb,
                color: state.whiteLedOn ? Colors.amber : Colors.grey,
              ),
              label: Text(state.whiteLedOn ? "Turn OFF" : "Turn ON"),
              onPressed: () => cubit.toggleWhiteLed(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: Icon(
                  state.darkCalibration != null
                      ? Icons.check_circle
                      : Icons.brightness_3,
                  color: state.darkCalibration != null ? Colors.green : null,
                ),
                label: Text(
                  state.darkCalibration != null ? "Clear Dark" : "Set Dark",
                ),
                onPressed: () {
                  if (state.darkCalibration != null) {
                    cubit.clearDarkCalibration();
                  } else {
                    cubit.saveDarkCalibration();
                  }
                },
              ),
              ElevatedButton.icon(
                icon: Icon(
                  state.whiteCalibration != null
                      ? Icons.check_circle
                      : Icons.brightness_high,
                  color: state.whiteCalibration != null ? Colors.green : null,
                ),
                label: Text(
                  state.whiteCalibration != null ? "Clear White" : "Set White",
                ),
                onPressed: () {
                  if (state.whiteCalibration != null) {
                    cubit.clearWhiteCalibration();
                  } else {
                    cubit.saveWhiteCalibration();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text("Export Spectrum JSON"),
            onPressed: () => cubit.exportJson(),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => cubit.disconnect(),
            child: const Text(
              "Disconnect",
              style: TextStyle(color: Colors.red),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
