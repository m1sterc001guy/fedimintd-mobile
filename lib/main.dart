import 'package:fedimintd_mobile/frb_generated.dart';
import 'package:fedimintd_mobile/startup_screen.dart';
import 'package:fedimintd_mobile/utils.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLogger.init();
  await RustLib.init();
  runApp(const Start());
}

class Start extends StatelessWidget {
  const Start({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fedimint Setup',
      theme: ThemeData.dark(),
      home: const SafeArea(child: StartupScreen()),
    );
  }
}
