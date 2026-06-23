import 'package:web/web.dart' as web;

/// Web implementation: builds a data URL and clicks a hidden anchor so the
/// browser saves the .ics file, which the OS opens into the default calendar.
void downloadIcs(String fileName, String content) {
  final href =
      'data:text/calendar;charset=utf-8,${Uri.encodeComponent(content)}';
  final anchor =
      web.document.createElement('a') as web.HTMLAnchorElement
        ..href = href
        ..download = fileName
        ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
}
