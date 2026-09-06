import 'dart:io';

/// Non-web fallback: writes [content] to [filename] in the current
/// working directory. There's no `path_provider` dependency in this
/// project to resolve a real "Downloads" folder on mobile, so this is a
/// best-effort save for desktop rather than a true download — swap in
/// `path_provider` + `share_plus` here if a native share sheet is wanted
/// on mobile.
Future<void> downloadCsvFile(String filename, String content) async {
  final file = File(filename);
  await file.writeAsString('\uFEFF$content');
  // ignore: avoid_print
  print('[csv_export] Wrote $filename to ${file.absolute.path}');
}