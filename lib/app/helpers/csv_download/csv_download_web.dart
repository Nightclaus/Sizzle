import 'dart:convert';
import 'dart:html' as html;

/// Triggers a browser download of [content] as [filename], via an
/// in-memory Blob and a hidden `<a download>` click — no server round
/// trip, no filesystem permission prompt.
Future<void> downloadCsvFile(String filename, String content) async {
  // A UTF-8 BOM up front so Excel opens accented characters / handles
  // correctly instead of guessing the wrong encoding.
  final bytes = utf8.encode('\uFEFF$content');
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}