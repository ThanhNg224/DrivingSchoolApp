import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';  

final Logger logger = Logger();

Future<Directory> createSessionFolder() async {
  final directory = await getApplicationDocumentsDirectory();
  final String sessionPath = '${directory.path}/session_${DateTime.now().toString().replaceAll(":", "_")}';

  final Directory sessionFolder = Directory(sessionPath);

  if (!sessionFolder.existsSync()) {
    try {
      sessionFolder.createSync(recursive: true);
      logger.i("✅ Session folder created: ${sessionFolder.path}");
    } catch (e) {
      logger.e("❌ ERROR: Failed to create session folder: $e");
    }
  } else {
    logger.i("📂 Session folder already exists: ${sessionFolder.path}");
  }

  return sessionFolder;
}
