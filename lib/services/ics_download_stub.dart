/// Non-web fallback. On native platforms a share-sheet would be wired here
/// later; for now the web build is the only target that downloads .ics files.
void downloadIcs(String fileName, String content) {
  // No-op on non-web platforms.
}

void openExternalUrl(String url) {
  // No-op on non-web platforms.
}
