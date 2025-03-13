// dont need to use this yet
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

/// Collects information about video chunks in the provided [sessionFolder]
/// but skips the merging step, keeping all individual chunk files.
Future<List<String>> collectSessionChunks(Directory sessionFolder) async {
  debugPrint("Collecting session chunks without merging");
  
  // List all .mp4 files (chunks) in the session folder
  final List<FileSystemEntity> chunkFiles = sessionFolder
      .listSync()
      .where((entity) => entity.path.endsWith('.mp4'))
      .toList();

  // Sort chunks by name (assuming they are named as 'chunk_01.mp4', 'chunk_02.mp4', etc.)
  chunkFiles.sort((a, b) => a.path.compareTo(b.path));
  
  // Create a file listing (for reference, not for FFmpeg)
  final String fileListPath = path.join(sessionFolder.path, 'video_chunks_list.txt');
  final File fileList = File(fileListPath);
  final IOSink sink = fileList.openWrite();
  
  final List<String> chunkPaths = [];
  
  for (var file in chunkFiles) {
    // Save the path to our return list
    chunkPaths.add(file.path);
    
    // Write to the reference file (optional)
    sink.writeln("${path.basename(file.path)}: ${file.path}");
  }
  
  await sink.flush();
  await sink.close();
  
  debugPrint("Found ${chunkPaths.length} video chunks. Keeping all individual files.");
  return chunkPaths;
}