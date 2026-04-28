#!/usr/bin/env python3
"""
MCP Client Wrapper para Docker MCP Gateway
Permite invocar herramientas MCP desde línea de comandos.

Uso:
  python3 mcp_client.py list-tools
  python3 mcp_client.py call <tool-name> '<json-args>'

Ejemplo:
  python3 mcp_client.py list-tools
  python3 mcp_client.py call context7_search '{"query": "Frappe Framework"}'
"""

import sys
import json
import uuid
import urllib.request
import urllib.error
import threading
import queue
import time

GATEWAY_URL = "http://localhost:8811/sse"
AUTH_TOKEN = "9vitgudodapodc2p0qankmrie0dd33pq6nd0ejet7z8fo3lutx"


def make_request(url, data=None, headers=None, method=None):
    """Make HTTP request using urllib."""
    req_headers = headers or {}
    if data and isinstance(data, dict):
        data = json.dumps(data).encode('utf-8')
        req_headers['Content-Type'] = 'application/json'
    
    req = urllib.request.Request(url, data=data, headers=req_headers, method=method)
    
    try:
        with urllib.request.urlopen(req) as response:
            return response.status, response.read().decode('utf-8')
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode('utf-8')
    except Exception as e:
        return 0, str(e)


def read_sse_stream(url, headers, response_queue):
    """Read SSE stream and put lines in queue."""
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req) as response:
            buffer = b""
            while True:
                chunk = response.read(1)
                if not chunk:
                    break
                buffer += chunk
                if b"\n" in buffer:
                    lines = buffer.split(b"\n")
                    for line in lines[:-1]:
                        decoded = line.decode('utf-8').strip()
                        if decoded:
                            response_queue.put(decoded)
                    buffer = lines[-1]
    except Exception as e:
        response_queue.put(f"ERROR: {e}")


def list_tools():
    """List all available tools from the MCP gateway."""
    headers = {
        "Authorization": f"Bearer {AUTH_TOKEN}",
        "Accept": "text/event-stream"
    }
    
    response_queue = queue.Queue()
    reader = threading.Thread(target=read_sse_stream, args=(GATEWAY_URL, headers, response_queue), daemon=True)
    reader.start()
    
    # Wait for endpoint event
    message_url = None
    start = time.time()
    while time.time() - start < 10:
        try:
            line = response_queue.get(timeout=1)
            if line.startswith("event: endpoint"):
                next_line = response_queue.get(timeout=1)
                if next_line.startswith("data: "):
                    message_url = GATEWAY_URL.replace("/sse", next_line[6:])
                    break
        except queue.Empty:
            continue
    
    if not message_url:
        print("Error: No se pudo obtener el endpoint de mensajes", file=sys.stderr)
        return []
    
    # Initialize
    init_msg = {
        "jsonrpc": "2.0",
        "id": str(uuid.uuid4()),
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "erp-mcp-client", "version": "1.0.0"}
        }
    }
    make_request(message_url, init_msg)
    time.sleep(0.5)
    
    # Send initialized notification
    make_request(message_url, {
        "jsonrpc": "2.0",
        "method": "notifications/initialized"
    })
    time.sleep(0.5)
    
    # List tools
    req_id = str(uuid.uuid4())
    list_msg = {
        "jsonrpc": "2.0",
        "id": req_id,
        "method": "tools/list"
    }
    make_request(message_url, list_msg)
    
    # Wait for response
    tools = []
    start = time.time()
    while time.time() - start < 15:
        try:
            line = response_queue.get(timeout=1)
            if line.startswith("data: "):
                data = json.loads(line[6:])
                if data.get("id") == req_id and "result" in data:
                    tools = data["result"].get("tools", [])
                    break
        except (queue.Empty, json.JSONDecodeError):
            continue
    
    return tools


def call_tool(tool_name, args):
    """Call an MCP tool with the given arguments."""
    headers = {
        "Authorization": f"Bearer {AUTH_TOKEN}",
        "Accept": "text/event-stream"
    }
    
    response_queue = queue.Queue()
    reader = threading.Thread(target=read_sse_stream, args=(GATEWAY_URL, headers, response_queue), daemon=True)
    reader.start()
    
    message_url = None
    start = time.time()
    while time.time() - start < 10:
        try:
            line = response_queue.get(timeout=1)
            if line.startswith("event: endpoint"):
                next_line = response_queue.get(timeout=1)
                if next_line.startswith("data: "):
                    message_url = GATEWAY_URL.replace("/sse", next_line[6:])
                    break
        except queue.Empty:
            continue
    
    if not message_url:
        return {"error": "No se pudo obtener el endpoint de mensajes"}
    
    # Initialize
    init_msg = {
        "jsonrpc": "2.0",
        "id": str(uuid.uuid4()),
        "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05",
            "capabilities": {},
            "clientInfo": {"name": "erp-mcp-client", "version": "1.0.0"}
        }
    }
    make_request(message_url, init_msg)
    time.sleep(0.5)
    
    make_request(message_url, {
        "jsonrpc": "2.0",
        "method": "notifications/initialized"
    })
    time.sleep(0.5)
    
    req_id = str(uuid.uuid4())
    call_msg = {
        "jsonrpc": "2.0",
        "id": req_id,
        "method": "tools/call",
        "params": {
            "name": tool_name,
            "arguments": args
        }
    }
    make_request(message_url, call_msg)
    
    result = None
    start = time.time()
    while time.time() - start < 30:
        try:
            line = response_queue.get(timeout=1)
            if line.startswith("data: "):
                data = json.loads(line[6:])
                if data.get("id") == req_id:
                    result = data
                    break
        except (queue.Empty, json.JSONDecodeError):
            continue
    
    return result or {"error": "Timeout esperando respuesta"}


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "list-tools":
        tools = list_tools()
        print(f"\n{'='*60}")
        print(f"HERRAMIENTAS MCP DISPONIBLES ({len(tools)} total)")
        print(f"{'='*60}\n")
        
        for tool in tools:
            name = tool.get("name", "unknown")
            desc = tool.get("description", "Sin descripción")[:100]
            print(f"  • {name}")
            print(f"    {desc}...")
            print()
    
    elif command == "call":
        if len(sys.argv) < 4:
            print("Uso: python3 mcp_client.py call <tool-name> '<json-args>'")
            sys.exit(1)
        
        tool_name = sys.argv[2]
        args = json.loads(sys.argv[3])
        result = call_tool(tool_name, args)
        print(json.dumps(result, indent=2, ensure_ascii=False))
    
    else:
        print(f"Comando desconocido: {command}")
        print(__doc__)
        sys.exit(1)
