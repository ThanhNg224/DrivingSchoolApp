import 'package:permission_handler/permission_handler.dart';

Future<bool> requestPermissions() async {
  // List all the permissions you actually need
  final statuses = await [
    Permission.camera,
    Permission.microphone,
    //Permission storing files in external storage or accessing user’s gallery:
    // Permission.mediaLibrary,
    // Permission.photos,
    // Permission.storage,
    
  ].request();

  // Check if all are granted
  return statuses.values.every((status) => status.isGranted);
}
