import 'package:carbine/frb_generated.dart';
import 'package:carbine/lib.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  _fedimintd();
  runApp(const MyApp());
}

Future<void> _fedimintd() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    await startFedimintd(path: dir.path);
  } catch (e) {
    print("Could not start fedimintd: $e");
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Hello, world!'),
        ),
      ),
    );
  }
}

