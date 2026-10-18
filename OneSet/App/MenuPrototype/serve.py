#!/usr/bin/env python3
"""THROWAWAY menu preview. Run from any directory with Python 3."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

root = Path(__file__).resolve().parents[3]
url = "http://127.0.0.1:8767/OneSet/App/MenuPrototype/?variant=A"
print(f"OneSet throwaway menu prototype: {url}", flush=True)
ThreadingHTTPServer(
    ("127.0.0.1", 8767), partial(SimpleHTTPRequestHandler, directory=str(root))
).serve_forever()
