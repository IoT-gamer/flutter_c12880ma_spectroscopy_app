import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/ble_cubit.dart';
import '../cubit/ble_state.dart';

class SpectralLineChart extends StatelessWidget {
  const SpectralLineChart({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BleCubit, BleState>(
      builder: (context, state) {
        final List<double> values = state.processedData;
        if (values.length < 288) {
          return const SizedBox(
            height: 320,
            child: Center(child: Text("Awaiting spectral data stream...")),
          );
        }

        // Generate coordinates: (Wavelength, Value)
        final List<FlSpot> spots = List.generate(288, (i) {
          final double wavelength = state.coefficients.getWavelength(i);
          return FlSpot(wavelength, values[i]);
        });

        final double minX = spots.first.x;
        final double maxX = spots.last.x;

        double maxY = state.showCalibratedData
            ? 110.0
            : (values.reduce((a, b) => a > b ? a : b) * 1.15).clamp(
                100.0,
                4096.0,
              );

        return Container(
          height: 340,
          padding: const EdgeInsets.fromLTRB(16, 24, 24, 12),
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: 0,
              maxY: maxY,
              gridData: const FlGridData(show: true, drawVerticalLine: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text(
                    "Wavelength (nm)",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 100,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          "${value.toInt()}",
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  axisNameWidget: Text(
                    state.showCalibratedData
                        ? "Reflectance (%)"
                        : "ADC Counts (12-bit)",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  sideTitles: const SideTitles(
                    showTitles: true,
                    reservedSize: 45,
                  ),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.1,
                  barWidth: 2,
                  color: Colors.blueAccent,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        Colors.blueAccent.withValues(alpha: 0.35),
                        Colors.blueAccent.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
