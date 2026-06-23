import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web implementation of "add to calendar".
///
/// The `download` attribute is ignored by iOS Safari, which is why the old
/// approach silently did nothing on iPhones/iPads. Instead we build a Blob URL
/// of type text/calendar and:
///   • on iOS, navigate straight to it so Safari shows the native "Add to
///     Calendar" sheet, and
///   • everywhere else, click an anchor with a `download` so the .ics saves and
///     the OS opens it into the default calendar app.
void downloadIcs(String fileName, String content) {
  final parts = [content.toJS].toJS;
  final blob = web.Blob(
    parts,
    web.BlobPropertyBag(type: 'text/calendar;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);

  final ua = web.window.navigator.userAgent;
  final isIos = ua.contains('iPhone') ||
      ua.contains('iPad') ||
      // iPadOS reports as Mac but is touch-capable.
      (ua.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1);

  if (isIos) {
    // Safari intercepts the text/calendar response and offers to add the event.
    web.window.location.href = url;
    return;
  }

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}

/// Opens an external URL in a new tab (used for the Google Calendar link).
void openExternalUrl(String url) {
  web.window.open(url, '_blank');
}
