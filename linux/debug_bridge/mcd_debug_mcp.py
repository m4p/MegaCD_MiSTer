#!/usr/bin/env python3

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any


SERVER_NAME = "mcd-debug-mcp"
SERVER_VERSION = "0.1.0"
DEFAULT_BASE_URL = "http://127.0.0.1:8080"
DEFAULT_TIMEOUT = 5.0

TARGET_NAMES = ["md68k_ram", "subcpu_ram", "wordram", "prgram", "backup_ram"]
READ_WIDTHS = ["8", "16", "32", "block"]
WRITE_WIDTHS = ["8", "16", "32"]


class ProtocolError(RuntimeError):
    pass


class BackendError(RuntimeError):
    def __init__(self, message: str, payload: Any | None = None):
        super().__init__(message)
        self.payload = payload


@dataclass
class HttpBridgeClient:
    base_url: str
    timeout: float

    def get_health(self) -> dict[str, Any]:
        return self._request_json("GET", "/api/health")

    def get_targets(self) -> dict[str, Any]:
        return self._request_json("GET", "/api/targets")

    def command(self, payload: dict[str, Any]) -> dict[str, Any]:
        return self._request_json("POST", "/api/command", payload)

    def _request_json(self, method: str, path: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
        url = urllib.parse.urljoin(self.base_url.rstrip("/") + "/", path.lstrip("/"))
        data = None
        headers = {}
        if payload is not None:
            data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
            headers["Content-Type"] = "application/json"
        request = urllib.request.Request(url=url, data=data, headers=headers, method=method)

        try:
            with urllib.request.urlopen(request, timeout=self.timeout) as response:
                raw = response.read()
        except urllib.error.HTTPError as exc:
            raw = exc.read()
            parsed = self._parse_json(raw, f"invalid JSON error body from {url}")
            if isinstance(parsed, dict):
                raise BackendError(f"HTTP {exc.code} from {url}", parsed) from exc
            raise BackendError(f"HTTP {exc.code} from {url}: {parsed}") from exc
        except urllib.error.URLError as exc:
            raise BackendError(f"failed to reach {url}: {exc.reason}") from exc

        parsed = self._parse_json(raw, f"invalid JSON response from {url}")
        if not isinstance(parsed, dict):
            raise BackendError(f"unexpected non-object JSON response from {url}", parsed)
        return parsed

    @staticmethod
    def _parse_json(raw: bytes, message: str) -> Any:
        try:
            return json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise BackendError(message) from exc


def make_tool(name: str, description: str, schema: dict[str, Any]) -> dict[str, Any]:
    return {
        "name": name,
        "description": description,
        "inputSchema": schema,
    }


TOOLS = [
    make_tool(
        "health",
        "Get health status for the configured MiSTer debug web server and backend link.",
        {"type": "object", "properties": {}, "additionalProperties": False},
    ),
    make_tool(
        "targets",
        "List known targets and their capabilities from the configured MiSTer.",
        {"type": "object", "properties": {}, "additionalProperties": False},
    ),
    make_tool(
        "pause",
        "Pause the MiSTer Sega CD core for deterministic memory access.",
        {"type": "object", "properties": {}, "additionalProperties": False},
    ),
    make_tool(
        "resume",
        "Resume the MiSTer Sega CD core after a pause.",
        {"type": "object", "properties": {}, "additionalProperties": False},
    ),
    make_tool(
        "get_access_mode",
        "Read the current bridge access mode.",
        {"type": "object", "properties": {}, "additionalProperties": False},
    ),
    make_tool(
        "set_access_mode",
        "Set the bridge access mode to paused or live.",
        {
            "type": "object",
            "properties": {
                "mode": {"type": "string", "enum": ["paused", "live"]},
            },
            "required": ["mode"],
            "additionalProperties": False,
        },
    ),
    make_tool(
        "get_target_caps",
        "Get capability data for all targets or one target.",
        {
            "type": "object",
            "properties": {
                "target": {"type": "string", "enum": TARGET_NAMES},
            },
            "additionalProperties": False,
        },
    ),
    make_tool(
        "read_memory",
        "Read memory from a target using width 8, 16, 32, or block.",
        {
            "type": "object",
            "properties": {
                "target": {"type": "string", "enum": TARGET_NAMES},
                "addr": {"type": "integer", "minimum": 0},
                "width": {"type": "string", "enum": READ_WIDTHS},
                "length": {"type": "integer", "minimum": 1, "maximum": 32},
            },
            "required": ["target", "addr", "width"],
            "additionalProperties": False,
        },
    ),
    make_tool(
        "write_memory",
        "Write memory to a target using width 8, 16, or 32.",
        {
            "type": "object",
            "properties": {
                "target": {"type": "string", "enum": TARGET_NAMES},
                "addr": {"type": "integer", "minimum": 0},
                "width": {"type": "string", "enum": WRITE_WIDTHS},
                "value": {"type": "integer", "minimum": 0},
            },
            "required": ["target", "addr", "width", "value"],
            "additionalProperties": False,
        },
    ),
    make_tool(
        "search_bytes",
        "Search a target range for the first occurrence of a byte pattern.",
        {
            "type": "object",
            "properties": {
                "target": {"type": "string", "enum": TARGET_NAMES},
                "addr": {"type": "integer", "minimum": 0},
                "length": {"type": "integer", "minimum": 1},
                "data": {
                    "type": "array",
                    "items": {"type": "integer", "minimum": 0, "maximum": 255},
                    "minItems": 1,
                    "maxItems": 32,
                },
            },
            "required": ["target", "addr", "length", "data"],
            "additionalProperties": False,
        },
    ),
    make_tool(
        "raw_command",
        "Send a raw command object directly to /api/command on the configured MiSTer web bridge.",
        {
            "type": "object",
            "properties": {
                "command": {"type": "object", "additionalProperties": True},
            },
            "required": ["command"],
            "additionalProperties": False,
        },
    ),
]

TOOLS_BY_NAME = {tool["name"]: tool for tool in TOOLS}


def read_message() -> dict[str, Any] | None:
    headers: dict[str, str] = {}
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            return None
        if line in (b"\r\n", b"\n"):
            break
        try:
            key, value = line.decode("utf-8").split(":", 1)
        except ValueError as exc:
            raise ProtocolError(f"invalid header line: {line!r}") from exc
        headers[key.strip().lower()] = value.strip()

    if "content-length" not in headers:
        raise ProtocolError("missing Content-Length header")

    try:
        length = int(headers["content-length"])
    except ValueError as exc:
        raise ProtocolError("invalid Content-Length header") from exc

    body = sys.stdin.buffer.read(length)
    if len(body) != length:
        raise ProtocolError("truncated message body")

    try:
        parsed = json.loads(body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ProtocolError("invalid JSON request body") from exc

    if not isinstance(parsed, dict):
        raise ProtocolError("request body must be a JSON object")
    return parsed


def write_message(payload: dict[str, Any]) -> None:
    encoded = json.dumps(payload, separators=(",", ":"), ensure_ascii=True).encode("utf-8")
    sys.stdout.buffer.write(f"Content-Length: {len(encoded)}\r\n\r\n".encode("ascii"))
    sys.stdout.buffer.write(encoded)
    sys.stdout.buffer.flush()


def jsonrpc_result(message_id: Any, result: Any) -> dict[str, Any]:
    return {"jsonrpc": "2.0", "id": message_id, "result": result}


def jsonrpc_error(message_id: Any, code: int, message: str, data: Any | None = None) -> dict[str, Any]:
    error: dict[str, Any] = {"code": code, "message": message}
    if data is not None:
        error["data"] = data
    return {"jsonrpc": "2.0", "id": message_id, "error": error}


def require_object(arguments: Any) -> dict[str, Any]:
    if arguments is None:
        return {}
    if not isinstance(arguments, dict):
        raise ValueError("arguments must be an object")
    return arguments


def require_string(arguments: dict[str, Any], key: str, allowed: list[str] | None = None) -> str:
    value = arguments.get(key)
    if not isinstance(value, str):
        raise ValueError(f"{key} must be a string")
    if allowed is not None and value not in allowed:
        raise ValueError(f"{key} must be one of: {', '.join(allowed)}")
    return value


def require_integer(arguments: dict[str, Any], key: str, minimum: int | None = None, maximum: int | None = None) -> int:
    value = arguments.get(key)
    if not isinstance(value, int):
        raise ValueError(f"{key} must be an integer")
    if minimum is not None and value < minimum:
        raise ValueError(f"{key} must be >= {minimum}")
    if maximum is not None and value > maximum:
        raise ValueError(f"{key} must be <= {maximum}")
    return value


def require_integer_array(
    arguments: dict[str, Any],
    key: str,
    *,
    minimum_length: int | None = None,
    maximum_length: int | None = None,
    minimum: int | None = None,
    maximum: int | None = None,
) -> list[int]:
    value = arguments.get(key)
    if not isinstance(value, list):
        raise ValueError(f"{key} must be an array")
    if minimum_length is not None and len(value) < minimum_length:
        raise ValueError(f"{key} must contain at least {minimum_length} items")
    if maximum_length is not None and len(value) > maximum_length:
        raise ValueError(f"{key} must contain at most {maximum_length} items")

    items: list[int] = []
    for index, item in enumerate(value):
        if not isinstance(item, int):
            raise ValueError(f"{key}[{index}] must be an integer")
        if minimum is not None and item < minimum:
            raise ValueError(f"{key}[{index}] must be >= {minimum}")
        if maximum is not None and item > maximum:
            raise ValueError(f"{key}[{index}] must be <= {maximum}")
        items.append(item)
    return items


def tool_response(payload: Any, is_error: bool = False) -> dict[str, Any]:
    text = json.dumps(payload, indent=2, sort_keys=False)
    response = {
        "content": [{"type": "text", "text": text}],
        "isError": is_error,
    }
    if isinstance(payload, dict):
        response["structuredContent"] = payload
    return response


def backend_tool_response(payload: dict[str, Any]) -> dict[str, Any]:
    return tool_response(payload, is_error=(payload.get("ok") is False))


def handle_tool_call(client: HttpBridgeClient, name: str, arguments: dict[str, Any]) -> dict[str, Any]:
    if name == "health":
        return backend_tool_response(client.get_health())

    if name == "targets":
        return backend_tool_response(client.get_targets())

    if name == "pause":
        return backend_tool_response(client.command({"cmd": "pause"}))

    if name == "resume":
        return backend_tool_response(client.command({"cmd": "resume"}))

    if name == "get_access_mode":
        return backend_tool_response(client.command({"cmd": "get_access_mode"}))

    if name == "set_access_mode":
        mode = require_string(arguments, "mode", ["paused", "live"])
        return backend_tool_response(client.command({"cmd": "set_access_mode", "mode": mode}))

    if name == "get_target_caps":
        payload: dict[str, Any] = {"cmd": "get_target_caps"}
        if "target" in arguments:
            payload["target"] = require_string(arguments, "target", TARGET_NAMES)
        return backend_tool_response(client.command(payload))

    if name == "read_memory":
        target = require_string(arguments, "target", TARGET_NAMES)
        addr = require_integer(arguments, "addr", minimum=0)
        width = require_string(arguments, "width", READ_WIDTHS)
        if width == "block":
            length = require_integer(arguments, "length", minimum=1, maximum=32)
            payload = {"cmd": "read_block", "target": target, "addr": addr, "length": length}
        else:
            payload = {"cmd": f"read{width}", "target": target, "addr": addr}
        return backend_tool_response(client.command(payload))

    if name == "write_memory":
        target = require_string(arguments, "target", TARGET_NAMES)
        addr = require_integer(arguments, "addr", minimum=0)
        width = require_string(arguments, "width", WRITE_WIDTHS)
        value = require_integer(arguments, "value", minimum=0)
        payload = {"cmd": f"write{width}", "target": target, "addr": addr, "value": value}
        return backend_tool_response(client.command(payload))

    if name == "search_bytes":
        target = require_string(arguments, "target", TARGET_NAMES)
        addr = require_integer(arguments, "addr", minimum=0)
        length = require_integer(arguments, "length", minimum=1)
        data = require_integer_array(arguments, "data", minimum_length=1, maximum_length=32, minimum=0, maximum=255)
        payload = {"cmd": "search_bytes", "target": target, "addr": addr, "length": length, "data": data}
        return backend_tool_response(client.command(payload))

    if name == "raw_command":
        command = arguments.get("command")
        if not isinstance(command, dict):
            raise ValueError("command must be an object")
        return backend_tool_response(client.command(command))

    raise ValueError(f"unknown tool: {name}")


def handle_request(client: HttpBridgeClient, request: dict[str, Any], chosen_protocol_version: str | None) -> tuple[dict[str, Any] | None, str | None]:
    message_id = request.get("id")
    method = request.get("method")
    params = request.get("params")

    if not isinstance(method, str):
        if message_id is None:
            return None, chosen_protocol_version
        return jsonrpc_error(message_id, -32600, "invalid request: missing method"), chosen_protocol_version

    if method == "initialize":
        try:
            arguments = require_object(params)
        except ValueError as exc:
            return jsonrpc_error(message_id, -32602, str(exc)), chosen_protocol_version
        protocol_version = arguments.get("protocolVersion")
        if not isinstance(protocol_version, str):
            protocol_version = chosen_protocol_version or "2024-11-05"
        result = {
            "protocolVersion": protocol_version,
            "capabilities": {"tools": {}},
            "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION},
        }
        return jsonrpc_result(message_id, result), protocol_version

    if method == "notifications/initialized":
        return None, chosen_protocol_version

    if method == "ping":
        return jsonrpc_result(message_id, {}), chosen_protocol_version

    if method == "tools/list":
        return jsonrpc_result(message_id, {"tools": TOOLS}), chosen_protocol_version

    if method == "tools/call":
        try:
            arguments = require_object(params)
            tool_args = require_object(arguments.get("arguments"))
        except ValueError as exc:
            return jsonrpc_error(message_id, -32602, str(exc)), chosen_protocol_version
        tool_name = arguments.get("name")
        if not isinstance(tool_name, str) or tool_name not in TOOLS_BY_NAME:
            return jsonrpc_error(message_id, -32602, "unknown tool"), chosen_protocol_version
        try:
            result = handle_tool_call(client, tool_name, tool_args)
        except ValueError as exc:
            return jsonrpc_error(message_id, -32602, str(exc)), chosen_protocol_version
        except BackendError as exc:
            payload = {
                "ok": False,
                "error": str(exc),
                "backend_payload": exc.payload,
            }
            return jsonrpc_result(message_id, tool_response(payload, is_error=True)), chosen_protocol_version
        return jsonrpc_result(message_id, result), chosen_protocol_version

    if message_id is None:
        return None, chosen_protocol_version
    return jsonrpc_error(message_id, -32601, f"method not found: {method}"), chosen_protocol_version


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Local MCP server for the MiSTer MegaCD debug web bridge")
    parser.add_argument(
        "--base-url",
        default=DEFAULT_BASE_URL,
        help=f"Base URL for mcd_debug_web.py on the MiSTer, default: {DEFAULT_BASE_URL}",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=DEFAULT_TIMEOUT,
        help=f"HTTP timeout in seconds, default: {DEFAULT_TIMEOUT}",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    client = HttpBridgeClient(base_url=args.base_url, timeout=args.timeout)
    chosen_protocol_version: str | None = None

    try:
        while True:
            request = read_message()
            if request is None:
                return 0
            response, chosen_protocol_version = handle_request(client, request, chosen_protocol_version)
            if response is not None:
                write_message(response)
    except ProtocolError as exc:
        print(f"{SERVER_NAME}: protocol error: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
