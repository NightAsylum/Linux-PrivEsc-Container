#!/usr/bin/env python3

from http.server import HTTPServer, BaseHTTPRequestHandler

HOST = "0.0.0.0"
PORT = "8080"    


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"running!\n")


print(f"Listening on {HOST}:{PORT}")
server = HTTPServer((HOST, PORT), Handler)
server.serve_forever()