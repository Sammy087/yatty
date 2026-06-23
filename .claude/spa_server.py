"""Tiny static server for the Flutter web build with SPA fallback.

Serves files from build/web; any unknown path (e.g. /book/xyz) falls back to
index.html so client-side routing works. Used only for local preview testing.
"""
import os
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8099
ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "build", "web")


class SpaHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def do_GET(self):
        path = self.translate_path(self.path)
        if not os.path.exists(path) or os.path.isdir(path):
            # No real file here → let the SPA router handle it.
            if not os.path.isfile(path):
                self.path = "/index.html"
        return super().do_GET()


ThreadingHTTPServer(("127.0.0.1", PORT), SpaHandler).serve_forever()
