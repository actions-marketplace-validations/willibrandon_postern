#!/usr/bin/env python3
"""Drive a postern binary through one LSP session over stdio.

Usage: stdio_smoke.py PATH_TO_POSTERN

Opens a broken postgresql.conf, expects diagnostics and a hover, then shuts
the server down. Exits non-zero when any step fails, so CI can run it on each
platform before the editor tests.
"""

import json
import os
import subprocess
import sys
import tempfile
import time

binary = sys.argv[1]
workdir = tempfile.mkdtemp()
path = os.path.join(workdir, "postgresql.conf")
with open(path, "w", encoding="utf-8") as handle:
    handle.write("port =\nshared_buffers = 128QB\nlisten_addreses = '*'\n")

process = subprocess.Popen(
    [binary], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE
)


def send(message):
    body = json.dumps(message).encode()
    process.stdin.write(b"Content-Length: %d\r\n\r\n" % len(body) + body)
    process.stdin.flush()


def receive(timeout=60):
    deadline = time.time() + timeout
    headers = b""
    while not headers.endswith(b"\r\n\r\n"):
        if time.time() > deadline:
            raise TimeoutError("no response from the server")
        chunk = process.stdout.read(1)
        if not chunk:
            stderr = process.stderr.read().decode(errors="replace")
            raise EOFError("server closed stdout; stderr: " + stderr[:2000])
        headers += chunk
    length = int(
        [h for h in headers.decode().split("\r\n") if h.lower().startswith("content-length")][0]
        .split(":")[1]
    )
    return json.loads(process.stdout.read(length))


def receive_response():
    while True:
        message = receive()
        if message.get("method") == "window/logMessage":
            print("log:", message["params"]["message"])
            continue
        return message


uri = "file:///" + path.replace(os.sep, "/").lstrip("/")
send(
    {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "processId": os.getpid(),
            "rootUri": None,
            "capabilities": {},
            "clientInfo": {"name": "stdio_smoke"},
            "initializationOptions": {"pg": 16},
        },
    }
)
result = receive_response()["result"]
assert result["serverInfo"]["name"] == "postern", result
print("initialize:", result["serverInfo"])

send({"jsonrpc": "2.0", "method": "initialized", "params": {}})
with open(path, encoding="utf-8") as handle:
    text = handle.read()
send(
    {
        "jsonrpc": "2.0",
        "method": "textDocument/didOpen",
        "params": {
            "textDocument": {
                "uri": uri,
                "languageId": "postgresql-conf",
                "version": 1,
                "text": text,
            }
        },
    }
)
diagnostics = None
while diagnostics is None:
    message = receive()
    if message.get("method") == "textDocument/publishDiagnostics":
        diagnostics = message["params"]["diagnostics"]
    elif message.get("method") == "window/logMessage":
        print("log:", message["params"]["message"])
for diagnostic in diagnostics:
    print("diagnostic line %d: %s" % (diagnostic["range"]["start"]["line"] + 1, diagnostic["message"]))
assert any("listen_addresses" in d["message"] for d in diagnostics), diagnostics

send(
    {
        "jsonrpc": "2.0",
        "id": 2,
        "method": "textDocument/hover",
        "params": {"textDocument": {"uri": uri}, "position": {"line": 1, "character": 3}},
    }
)
hover = receive_response()["result"]
assert "shared_buffers" in hover["contents"]["value"], hover
print("hover: ok")

send({"jsonrpc": "2.0", "id": 3, "method": "shutdown", "params": None})
receive_response()
send({"jsonrpc": "2.0", "method": "exit", "params": None})
code = process.wait(timeout=30)
print("exit code:", code)
sys.exit(0 if code == 0 else 1)
