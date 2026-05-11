#!/usr/bin/env python3
"""
Transparent HTTP-recording proxy for the Catalyst → Raiko traffic.

Listens on $LISTEN (default 0.0.0.0:18080), forwards every request to
$UPSTREAM (default http://host.docker.internal:8082), and writes one JSONL
record per exchange to $OUT (default /captures/exchanges.jsonl).

Each record:
  {
    "ts": "2026-05-08T06:55:01Z",
    "method": "POST",
    "path": "/v3/proof/batch/realtime",
    "req_headers": {...},
    "req_body_b64": "...",   # request body, base64 (handles binary cleanly)
    "req_body_text": "...",  # set if utf-8 decodes; otherwise null
    "status": 200,
    "resp_headers": {...},
    "resp_body_b64": "...",
    "resp_body_text": "..."
  }

Stdlib only — no pip install needed. Drop into a busybox/alpine python image
or run on the host.
"""

import base64
import datetime as _dt
import http.server
import json
import os
import sys
import threading
import urllib.error
import urllib.request

LISTEN_HOST, LISTEN_PORT = (os.environ.get("LISTEN", "0.0.0.0:18080").split(":") + ["18080"])[:2]
LISTEN_PORT = int(LISTEN_PORT)
UPSTREAM = os.environ.get("UPSTREAM", "http://host.docker.internal:8082").rstrip("/")
OUT_PATH = os.environ.get("OUT", "/captures/exchanges.jsonl")

os.makedirs(os.path.dirname(OUT_PATH) or ".", exist_ok=True)
_lock = threading.Lock()


def _now() -> str:
    return _dt.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")


def _try_text(b: bytes) -> "str | None":
    try:
        return b.decode("utf-8")
    except UnicodeDecodeError:
        return None


def _record(entry: dict) -> None:
    line = json.dumps(entry, separators=(",", ":")) + "\n"
    with _lock:
        with open(OUT_PATH, "a", encoding="utf-8") as f:
            f.write(line)
    # Also echo a one-line summary to stdout for live visibility.
    summary = (
        f"[{entry['ts']}] {entry['method']} {entry['path']} "
        f"→ HTTP {entry.get('status', '?')} "
        f"req={len(entry.get('req_body_b64') or '')//4*3}B "
        f"resp={len(entry.get('resp_body_b64') or '')//4*3}B"
    )
    print(summary, flush=True)


class Proxy(http.server.BaseHTTPRequestHandler):
    # Quieter default access log — we already write our own.
    def log_message(self, fmt, *args):  # noqa: N802 (stdlib API)
        return

    def _proxy(self):
        method = self.command
        path = self.path
        length = int(self.headers.get("Content-Length") or 0)
        req_body = self.rfile.read(length) if length else b""
        # Strip the hop-by-hop headers and Host (urllib will set its own).
        skip = {"host", "content-length", "connection", "transfer-encoding"}
        fwd_headers = {k: v for k, v in self.headers.items() if k.lower() not in skip}

        upstream_url = f"{UPSTREAM}{path}"
        req = urllib.request.Request(upstream_url, data=req_body or None, method=method, headers=fwd_headers)

        status = 502
        resp_headers: dict = {}
        resp_body = b""
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                status = resp.status
                resp_headers = dict(resp.headers.items())
                resp_body = resp.read()
        except urllib.error.HTTPError as e:
            status = e.code
            resp_headers = dict(e.headers.items()) if e.headers else {}
            resp_body = e.read() if e.fp else b""
        except Exception as e:  # noqa: BLE001
            err = str(e).encode()
            self.send_response(502)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(err)))
            self.end_headers()
            self.wfile.write(err)
            _record({
                "ts": _now(), "method": method, "path": path,
                "req_headers": dict(self.headers.items()),
                "req_body_b64": base64.b64encode(req_body).decode(),
                "req_body_text": _try_text(req_body),
                "status": 502, "resp_headers": {}, "resp_body_b64": base64.b64encode(err).decode(),
                "resp_body_text": err.decode(errors="replace"),
                "error": str(e),
            })
            return

        # Write recorded exchange before flushing to client (so a panic on the
        # client side doesn't lose the capture).
        _record({
            "ts": _now(), "method": method, "path": path,
            "req_headers": dict(self.headers.items()),
            "req_body_b64": base64.b64encode(req_body).decode(),
            "req_body_text": _try_text(req_body),
            "status": status,
            "resp_headers": resp_headers,
            "resp_body_b64": base64.b64encode(resp_body).decode(),
            "resp_body_text": _try_text(resp_body),
        })

        # Forward response to client.
        self.send_response(status)
        skip_resp = {"transfer-encoding", "connection", "content-length"}
        for k, v in resp_headers.items():
            if k.lower() not in skip_resp:
                self.send_header(k, v)
        self.send_header("Content-Length", str(len(resp_body)))
        self.end_headers()
        self.wfile.write(resp_body)

    do_GET = do_POST = do_PUT = do_DELETE = do_PATCH = do_HEAD = _proxy


def main():
    print(f"blob_proxy listening on {LISTEN_HOST}:{LISTEN_PORT} → {UPSTREAM}", flush=True)
    print(f"writing JSONL to {OUT_PATH}", flush=True)
    server = http.server.ThreadingHTTPServer((LISTEN_HOST, LISTEN_PORT), Proxy)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        sys.exit(0)


if __name__ == "__main__":
    main()