#!/usr/bin/env python3
# opcua_bridge.py
# OPC-UA client bridge for industrial robots (asyncua) exposed over a JSON-lines
# TCP server so Godot can drive it via PythonBridge. Commands:
#   connect {host, port}      -> open an OPC-UA session
#   disconnect                -> close the session
#   read      {node_id}       -> read one node value
#   write     {node_id, value}-> write one node value
#   read_many {node_ids}      -> read several node values (ordered)
#   write_many{node_ids, values} -> write several node values (ordered)
#   shutdown                  -> close session and exit
# The asyncio event loop runs on a background thread; client ops are scheduled
# onto it with run_coroutine_threadsafe.

import sys
import json
import socket
import argparse
import asyncio
import threading

try:
    from asyncua import Client
    from asyncua import ua
    HAS_ASYNCUA = True
except ImportError:
    Client = None
    ua = None
    HAS_ASYNCUA = False


class OPCUABridge:
    def __init__(self):
        self.client = None
        self.loop = asyncio.new_event_loop()
        self.thread = threading.Thread(target=self.loop.run_forever, daemon=True)
        self.thread.start()

    def _run(self, coro, timeout=15.0):
        future = asyncio.run_coroutine_threadsafe(coro, self.loop)
        return future.result(timeout=timeout)

    def connect(self, host, port):
        if not HAS_ASYNCUA:
            raise RuntimeError("asyncua is not installed (pip install asyncua)")

        async def _connect():
            if self.client is not None:
                return
            url = "opc.tcp://%s:%d" % (host, port)
            self.client = Client(url)
            await self.client.connect()

        self._run(_connect())

    def disconnect(self):
        async def _disconnect():
            if self.client is not None:
                try:
                    await self.client.disconnect()
                finally:
                    self.client = None

        self._run(_disconnect())

    def read(self, node_id):
        async def _read():
            if self.client is None:
                raise RuntimeError("Not connected")
            node = self.client.get_node(node_id)
            return await node.read_value()

        return self._run(_read())

    def write(self, node_id, value):
        async def _write():
            if self.client is None:
                raise RuntimeError("Not connected")
            node = self.client.get_node(node_id)
            await node.write_value(value)

        self._run(_write())

    def read_many(self, node_ids):
        async def _read_many():
            if self.client is None:
                raise RuntimeError("Not connected")
            out = []
            for nid in node_ids:
                node = self.client.get_node(nid)
                out.append(await node.read_value())
            return out

        return self._run(_read_many())

    def write_many(self, node_ids, values):
        async def _write_many():
            if self.client is None:
                raise RuntimeError("Not connected")
            for nid, val in zip(node_ids, values):
                node = self.client.get_node(nid)
                await node.write_value(val)

        self._run(_write_many())


def process_cmd(cmd, bridge):
    action = cmd.get("cmd", "")
    if action == "connect":
        bridge.connect(cmd.get("host", ""), cmd.get("port", 4840))
        return {"status": "ok"}
    if action == "disconnect":
        bridge.disconnect()
        return {"status": "ok"}
    if action == "read":
        value = bridge.read(cmd.get("node_id", ""))
        return {"status": "ok", "value": value}
    if action == "write":
        bridge.write(cmd.get("node_id", ""), cmd.get("value", 0))
        return {"status": "ok"}
    if action == "read_many":
        values = bridge.read_many(cmd.get("node_ids", []))
        return {"status": "ok", "values": values}
    if action == "write_many":
        bridge.write_many(cmd.get("node_ids", []), cmd.get("values", []))
        return {"status": "ok"}
    if action == "shutdown":
        try:
            bridge.disconnect()
        except Exception:
            pass
        return {"status": "ok", "cmd": "shutdown"}
    return {"status": "error", "message": "Unknown command: %s" % action}


def run_tcp_server(port):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("127.0.0.1", port))
    server.listen(1)
    sys.stderr.write("OPC-UA bridge listening on 127.0.0.1:%d\n" % port)
    sys.stderr.flush()

    conn, _addr = server.accept()
    bridge = OPCUABridge()
    buffer = ""
    while True:
        try:
            data = conn.recv(4096).decode("utf-8")
            if not data:
                break
            buffer += data
            while "\n" in buffer:
                line, buffer = buffer.split("\n", 1)
                line = line.strip()
                if not line:
                    continue
                try:
                    cmd = json.loads(line)
                except json.JSONDecodeError:
                    conn.sendall((json.dumps({"status": "error", "message": "Invalid JSON"}) + "\n").encode("utf-8"))
                    continue
                try:
                    response = process_cmd(cmd, bridge)
                except Exception as e:
                    response = {"status": "error", "message": str(e)}
                conn.sendall((json.dumps(response) + "\n").encode("utf-8"))
                if cmd.get("cmd") == "shutdown":
                    conn.close()
                    server.close()
                    return
        except (ConnectionResetError, BrokenPipeError):
            break
    conn.close()
    server.close()


def main():
    parser = argparse.ArgumentParser(description="OPC-UA robot bridge")
    parser.add_argument("--tcp", action="store_true", help="Run in TCP server mode")
    parser.add_argument("--port", type=int, default=9890, help="TCP port (default: 9890)")
    args = parser.parse_args()
    if args.tcp:
        run_tcp_server(args.port)


if __name__ == "__main__":
    main()
