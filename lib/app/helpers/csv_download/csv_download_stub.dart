/// Used only if neither dart.library.html nor dart.library.io is
/// available for the current compile target.
Future<void> downloadCsvFile(String filename, String content) async {
  throw UnsupportedError('CSV download is not supported on this platform.');
}