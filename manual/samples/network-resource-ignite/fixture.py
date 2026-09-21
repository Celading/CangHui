"""Local-only streaming fixture. Emits its loopback origin; Ctrl-C stops it."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import struct
import zlib


def chunk(kind, data):
    return struct.pack("!I", len(data)) + kind + data + struct.pack("!I", zlib.crc32(kind + data))


PNG = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack("!2I5B", 2, 2, 8, 6, 0, 0, 0))
       + chunk(b"IDAT", zlib.compress((b"\0" + bytes([20, 120, 220, 255]) * 2) * 2)) + chunk(b"IEND", b""))


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def handle(self):
        try:
            super().handle()
        except (BrokenPipeError, ConnectionResetError):
            pass  # Rejected responses may reset while awaiting the next request.

    def do_GET(self):
        if self.path == "/redirect":
            self.send_response(302)
            self.send_header("Location", "/must-not-visit")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        if self.path == "/must-not-visit":
            print("FAIL redirect followed", flush=True)
        self.send_response(200)
        data = PNG if self.path == "/image" else b"x" * (8192 if "large" in self.path else 3)
        self.send_header("Content-Type", "image/png" if self.path == "/image" else "application/octet-stream")
        if self.path == "/gzip":
            self.send_header("Content-Encoding", "gzip")
        if self.path == "/chunked-large":
            self.send_header("Transfer-Encoding", "chunked")
        else:
            self.send_header("Content-Length", str(100 if self.path == "/truncated" else len(data)))
        self.end_headers()
        try:
            if self.path == "/chunked-large":
                for offset in range(0, len(data), 1024):
                    self.wfile.write(b"400\r\n" + data[offset:offset + 1024] + b"\r\n")
                self.wfile.write(b"0\r\n\r\n")
            else:
                self.wfile.write(data)
            self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass  # Expected when the client rejects a bounded response.
        if self.path == "/truncated":
            self.close_connection = True


if __name__ == "__main__":
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    print(f"http://127.0.0.1:{server.server_port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
