import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'cubit/ble_cubit.dart';
import 'screens/spectrometer_screen.dart';

void main() {
  runApp(const C12880maApp());
}

class C12880maApp extends StatelessWidget {
  const C12880maApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'C12880MA Spectrometer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: BlocProvider(
        create: (context) => BleCubit(),
        child: const SpectrometerScreen(),
      ),
    );
  }
}
