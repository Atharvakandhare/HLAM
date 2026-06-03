import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> saveAndShareFile(List<int> bytes, String fileName, {String? shareText}) async {
  final directory = await getApplicationDocumentsDirectory();
  final path = "${directory.path}/$fileName";
  final file = File(path);
  await file.create(recursive: true);
  await file.writeAsBytes(bytes);
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(path)],
      text: shareText ?? 'HL Attendee File',
    ),
  );
}
