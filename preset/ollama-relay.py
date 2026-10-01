#!/usr/bin/env python3
"""Small HTTP relay for a containerized Pi client talking to host Ollama.

Ollama rejects requests whose Host header names the Docker network alias. This
relay keeps the Pi container on an internal network while presenting the Host
header Ollama expects at the host boundary.
"""

from __future__ import annotations

import argparse
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


HOP_BY_HOP = {
    "connection",
    "keep-alive",
    "proxy-authenticate",
    "proxy-authorization",
    "te",
    "trailer",
    "transfer-encoding",
    "upgrade",
}


class OllamaRelayHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    upstream_host = "host.docker.internal"
    upstream_port = 11434

    def _relay(self) -> None:
        content_length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(content_length) if content_length else None
        headers = {
            name: value
            for name, value in self.headers.items()
            if name.lower() not in HOP_BY_HOP | {"host"}
        }
        headers["Host"] = f"localhost:{self.upstream_port}"
        headers["Connection"] = "close"

        upstream = http.client.HTTPConnection(
            self.upstream_host,
            self.upstream_port,
            timeout=3600,
        )
        response_started = False
        try:
            upstream.request(self.command, self.path, body=body, headers=headers)
            response = upstream.getresponse()
            self.send_response(response.status, response.reason)
            for name, value in response.getheaders():
                if name.lower() not in HOP_BY_HOP | {"content-length"}:
                    self.send_header(name, value)
            self.send_header("Connection", "close")
            self.end_headers()
            response_started = True
            while chunk := response.read(64 * 1024):
                self.wfile.write(chunk)
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass
        except Exception as error:  # pragma: no cover - exercised by live preflight.
            if not response_started:
                message = f"Ollama relay error: {error}\n".encode()
                self.send_response(502)
                self.send_header("Content-Type", "text/plain; charset=utf-8")
                self.send_header("Content-Length", str(len(message)))
                self.send_header("Connection", "close")
                self.end_headers()
                self.wfile.write(message)
        finally:
            self.close_connection = True
            upstream.close()

    do_GET = _relay
    do_HEAD = _relay
    do_POST = _relay
    do_DELETE = _relay

    def log_message(self, format: str, *args: object) -> None:
        return


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--listen-port", type=int, default=11434)
    parser.add_argument("--upstream-host", default="host.docker.internal")
    parser.add_argument("--upstream-port", type=int, default=11434)
    args = parser.parse_args()

    OllamaRelayHandler.upstream_host = args.upstream_host
    OllamaRelayHandler.upstream_port = args.upstream_port
    server = ThreadingHTTPServer(("0.0.0.0", args.listen_port), OllamaRelayHandler)
    server.serve_forever()


if __name__ == "__main__":
    main()
