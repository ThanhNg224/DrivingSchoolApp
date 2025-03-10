
import 'package:http/http.dart' as http;

import 'package:logger/logger.dart';

Future<void> verifyFace(String imagePath) async {
  var logger = Logger();
  var request = http.MultipartRequest('POST', Uri.parse('YOUR_BACKEND_API'));
  request.files.add(await http.MultipartFile.fromPath('file', imagePath));
  var response = await request.send();
  if (response.statusCode == 200) {
    logger.i("Face Verified");
  } else {
    logger.e("Face Mismatch");
  }
}
