import 'package:flutter/material.dart';
import 'app/bootstrap.dart';
import 'app/app.dart';

export 'app/app.dart' show DioufyApp;

Future<void> main() async {
  await AppBootstrap.initialize();
  runApp(const DioufyApp());
}

