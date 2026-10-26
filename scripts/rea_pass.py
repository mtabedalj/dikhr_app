#!/usr/bin/env python3
"""Drive REA's MCP server over stdio in ONE persistent session:
open the Athkar binary (bridged Hopper), then run all verification queries."""
import asyncio, json, os, sys, pathlib, re

ENV = dict(os.environ, REA_HOPPER_STARTUP_TIMEOUT_MS="600000")
CMD = ["npx", "-y", "rea-agents@6.7.0", "mcp"]
TARGET = "/Users/mabedalj/athkari_app/target/athkar"
OUT = pathlib.Path("/Users/mabedalj/athkari_app/notes/verify_raw")
OUT.mkdir(parents=True, exist_ok=True)

PATTERNS = ["khatmah", "checkin", "TimeMoments", "duha", "dhuhr"]

class MCP:
    def __init__(self):
        self.proc = None
        self.next_id = 1
        self.pending = {}

    async def start(self):
        self.proc = await asyncio.create_subprocess_exec(
            *CMD, env=ENV, stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL,
            limit=20_000_000)
        self.reader = asyncio.create_task(self._read())

    async def _read(self):
        while True:
            line = await self.proc.stdout.readline()
            if not line:
                break
            try:
                msg = json.loads(line)
            except Exception:
                continue
            mid = msg.get("id")
            if mid in self.pending:
                self.pending[mid].set_result(msg)

    async def call(self, method, params=None, timeout=900):
        mid = self.next_id; self.next_id += 1
        fut = asyncio.get_running_loop().create_future()
        self.pending[mid] = fut
        body = json.dumps({"jsonrpc": "2.0", "id": mid, "method": method, "params": params or {}})
        self.proc.stdin.write(body.encode() + b"\n")
        await self.proc.stdin.drain()
        return await asyncio.wait_for(fut, timeout)

    async def tool(self, name, arguments, timeout=900):
        resp = await self.call("tools/call", {"name": name, "arguments": arguments}, timeout)
        result = resp.get("result", {})
        # tool results carry structured content; keep the whole envelope
        return result

async def main():
    mcp = MCP()
    await mcp.start()
    init = await mcp.call("initialize", {
        "protocolVersion": "2024-11-05",
        "capabilities": {},
        "clientInfo": {"name": "dikhr-verify", "version": "1.0"}})
    mcp.proc.stdin.write(b'{"jsonrpc":"2.0","method":"notifications/initialized"}\n')
    await mcp.proc.stdin.drain()
    tools = await mcp.call("tools/list", {})
    names = [t["name"] for t in tools.get("result", {}).get("tools", [])]
    (OUT / "tools.json").write_text(json.dumps(names, indent=1))

    # Open the binary target
    open_result = await mcp.tool("open_binary", {"path": TARGET}, timeout=900)
    (OUT / "open_binary.json").write_text(json.dumps(open_result, ensure_ascii=False, indent=1)[:2000000])
    print("open_binary done", flush=True)

    jobs = [
        ("search_strings", "streak"),
        ("search_strings", "wird"),
        ("search_procedures", "Khatmah[A-Za-z]*"),
        ("search_procedures", "[Ss]treak"),
        ("search_procedures", "Checkin[A-Za-z]*|checkin[A-Za-z]*"),
        ("search_procedures", "TimeMom|TimeMoment"),
    ]
    for tool, pattern in jobs:
        outname = f"{tool}_" + re.sub(r'\W+', '_', pattern) + ".json"
        try:
            r = await mcp.tool(tool, {"pattern": pattern}, timeout=600)
            (OUT / outname).write_text(json.dumps(r, ensure_ascii=False)[:4000000])
            print(tool, pattern, "done", flush=True)
        except Exception as e:
            (OUT / outname).write_text(json.dumps({"error": str(e)}))
            print(tool, pattern, "FAILED", e, flush=True)

    # close the session to release the bridge cleanly
    try:
        close = await mcp.tool("close_binary", {"path": TARGET}, timeout=600)
        (OUT / "close_binary.json").write_text(json.dumps(close, ensure_ascii=False)[:500000])
        print("close_binary done", flush=True)
    except Exception as e:
        print("close_binary failed", e, flush=True)
    mcp.proc.terminate()

if __name__ == "__main__":
    asyncio.run(main())