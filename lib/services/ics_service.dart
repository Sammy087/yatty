import 'ics_download_stub.dart'
    if (dart.library.js_interop) 'ics_download_web.dart';

/// Builds RFC-5545 .ics calendar files and (on web) triggers a download so the
/// customer can add the appointment to their own device calendar.
class IcsService {
  /// Returns the text of a single-event .ics file.
  static String build({
    required String uid,
    required String title,
    required DateTime start,
    required DateTime end,
    String description = '',
    String location = '',
  }) {
    String fold(String s) => s.replaceAll('\n', '\\n').replaceAll(',', '\\,');
    final now = DateTime.now().toUtc();
    final buf = StringBuffer()
      ..writeln('BEGIN:VCALENDAR')
      ..writeln('VERSION:2.0')
      ..writeln('PRODID:-//yatty//booking//EN')
      ..writeln('CALSCALE:GREGORIAN')
      ..writeln('METHOD:PUBLISH')
      ..writeln('BEGIN:VEVENT')
      ..writeln('UID:$uid@yatty-cf0d5')
      ..writeln('DTSTAMP:${_utc(now)}')
      ..writeln('DTSTART:${_utc(start.toUtc())}')
      ..writeln('DTEND:${_utc(end.toUtc())}')
      ..writeln('SUMMARY:${fold(title)}')
      ..writeln('DESCRIPTION:${fold(description)}')
      ..writeln('LOCATION:${fold(location)}')
      ..writeln('STATUS:CONFIRMED')
      ..writeln('END:VEVENT')
      ..writeln('END:VCALENDAR');
    return buf.toString();
  }

  /// Triggers a browser download of the given .ics content (or, on iOS, the
  /// native "Add to Calendar" sheet).
  static void download(String fileName, String icsContent) =>
      downloadIcs(fileName, icsContent);

  /// A Google Calendar "add event" link, prefilled — one tap to save for anyone
  /// using Google Calendar.
  static String googleCalendarUrl({
    required String title,
    required DateTime start,
    required DateTime end,
    String description = '',
    String location = '',
  }) {
    final dates = '${_utc(start.toUtc())}/${_utc(end.toUtc())}';
    final params = {
      'action': 'TEMPLATE',
      'text': title,
      'dates': dates,
      'details': description,
      'location': location,
    };
    final query = params.entries
        .map((e) =>
            '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return 'https://calendar.google.com/calendar/render?$query';
  }

  /// Opens [url] in a new tab (web only).
  static void openUrl(String url) => openExternalUrl(url);

  static String _utc(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}${two(d.month)}${two(d.day)}T'
        '${two(d.hour)}${two(d.minute)}${two(d.second)}Z';
  }
}
