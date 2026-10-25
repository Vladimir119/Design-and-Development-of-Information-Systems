import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import psycopg


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path not in ("/", "/health"):
            self.reply(404, {"error": "not found"})
            return
        try:
            with psycopg.connect(
                host=os.environ["DB_HOST"],
                dbname=os.environ["DB_NAME"],
                user=os.environ["DB_USER"],
                password=os.environ["DB_PASSWORD"],
                connect_timeout=3,
                options="-c statement_timeout=3000",
            ) as conn:
                if self.path == "/health":
                    conn.execute("SELECT visits FROM counter WHERE id = 1").fetchone()
                    data = {"status": "ok", "database": "ok"}
                else:
                    visits = conn.execute(
                        "UPDATE counter SET visits = visits + 1 WHERE id = 1 RETURNING visits"
                    ).fetchone()[0]
                    data = {"message": os.getenv("APP_MESSAGE", "Lab 2"), "visits": visits}
            self.reply(200, data)
        except psycopg.Error:
            self.reply(503, {"error": "database unavailable"})

    def reply(self, status, data):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
