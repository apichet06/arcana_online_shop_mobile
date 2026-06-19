import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/arcana_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const configuredEnvFile = String.fromEnvironment('ENV_FILE');
  const isProduction = bool.fromEnvironment('dart.vm.product');
  final defaultEnvFile = isProduction ? '.env.production.local' : '.env.local';
  final envFile = configuredEnvFile.isNotEmpty
      ? configuredEnvFile
      : defaultEnvFile;

  await dotenv.load(fileName: envFile);

  runApp(const ArcanaApp());
}
