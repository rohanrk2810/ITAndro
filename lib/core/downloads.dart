import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Fetches a protected file (the request carries the bearer token) into the app's temp folder.
Future<File> downloadToTemp(Dio dio, String path, String filename) async {
  final dir = await getTemporaryDirectory();
  // Names come from the server: keep only a safe file name so nothing can escape the folder.
  final safe = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final file = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$safe');
  await dio.download(path, file.path);
  return file;
}

/// Downloads and hands the file to whichever app on the phone opens it. Returns an error message, or null.
Future<String?> downloadAndOpen(Dio dio, String path, String filename) async {
  final file = await downloadToTemp(dio, path, filename);
  final result = await OpenFilex.open(file.path);
  return result.type == ResultType.done ? null : 'No app on this phone can open ${filename.split('.').last.toUpperCase()} files.';
}
