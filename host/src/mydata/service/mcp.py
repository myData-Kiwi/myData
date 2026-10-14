"""MCP server over the same tool registry, so any MCP agent goes through the same permission gate.

Served as Streamable HTTP at /mcp on the host's localhost server, behind the same token.
- tools/list: every tool in the registry, with its input schema and permission in the description.
- tools/call: Registry.invoke with caller "mcp". An irreversible tool comes back as
  {"status": "pending_approval", "approval_id": ...}: it has NOT run. Only the user, through the
  host's approval endpoint, can run it. There is no MCP tool for approving.

Real data stays away from agents: in real mode (a linked account; see modes.py) a caller with an agent
token gets no tools, and a call is refused, because the tools would return the user's mirrored contacts
and events. Before accounts existed agents only ever saw the fake demo data, and letting them read real
data is not something the owner has decided. App tokens (our own apps) are not affected.
"""

from __future__ import annotations

import json
import logging
from typing import Any

import anyio
import mcp_types as types
from mcp.server import Server, ServerRequestContext
from mcp.server.streamable_http_manager import StreamableHTTPSessionManager
from mcp.server.transport_security import TransportSecuritySettings

from .. import __version__
from ..tools import Registry
from ..tools.registry import ModeRefused

LOCAL_HOSTS = ["127.0.0.1", "localhost", "[::1]", "127.0.0.1:*", "localhost:*", "[::1]:*"]
LOCAL_ORIGINS = ["http://127.0.0.1:*", "http://localhost:*", "http://[::1]:*"]

_ERRORS = {"unknown_tool", "invalid_args", "bad_date", "error"}

logger = logging.getLogger("mydata.mcp")


REAL_DATA_REFUSED = ("This host holds the user's real contacts and calendars. Agents cannot read them; "
                     "only the user's own myData apps can.")


def _principal(ctx: ServerRequestContext[Any]):
    return getattr(getattr(ctx.request, "state", None), "principal", None)


def _shut_out(registry: Registry, principal) -> bool:
    """True when this caller may not use the tools now: an agent (or an unknown caller) in real mode."""
    if registry.mode == "demo":
        return False
    return principal is None or getattr(principal, "kind", None) != "app"


def build_mcp(registry: Registry) -> StreamableHTTPSessionManager:
    def tool_list() -> list[types.Tool]:
        return [types.Tool.model_validate({
            "name": t["name"],
            "description": f"{t['description']} [permission: {t['permission']}]",
            "inputSchema": t["input_schema"],
        }) for t in registry.describe()]

    async def on_list_tools(ctx: ServerRequestContext[Any], params: types.PaginatedRequestParams | None
                            ) -> types.ListToolsResult:
        if _shut_out(registry, _principal(ctx)):
            return types.ListToolsResult(tools=[])
        return types.ListToolsResult(tools=tool_list())

    async def on_call_tool(ctx: ServerRequestContext[Any], params: types.CallToolRequestParams
                           ) -> types.CallToolResult:
        principal = _principal(ctx)
        caller = principal.label if principal else "mcp"
        # The registry checks the mode and runs the call as one step, so a switch to real mode cannot land
        # between an agent's check and its run.
        modes = None if getattr(principal, "kind", None) == "app" else ("demo",)
        try:
            inv = await anyio.to_thread.run_sync(
                lambda: registry.invoke(params.name, params.arguments or {}, caller=caller, modes=modes))
        except ModeRefused:
            logger.info("tool call", extra={"fields": {"tool": params.name, "caller": caller,
                                                       "status": "refused", "error": "real data"}})
            return types.CallToolResult(content=[types.TextContent(text=json.dumps(
                {"status": "refused", "error": REAL_DATA_REFUSED}))], is_error=True)
        except Exception as e:  # a bug in a tool or the resolver is an error result, never a crashed request
            logger.exception("mcp tool call failed")
            return types.CallToolResult(content=[types.TextContent(text=json.dumps(
                {"status": "error", "error": f"{type(e).__name__}"}))], is_error=True)
        if inv.status == "pending_approval":
            payload = {"status": "pending_approval", "approval_id": inv.approval.id, "summary": inv.approval.summary,
                       "message": "Held for the user's approval in myData. It has not happened."}
        elif inv.status == "ambiguous":
            payload = {"status": "ambiguous", "options": inv.options,
                       "message": "Several matches. Ask the user which one they mean."}
        else:
            payload = {"status": inv.status, "result": inv.result}
            if inv.error:
                payload["error"] = inv.error
        return types.CallToolResult(content=[types.TextContent(text=json.dumps(payload, ensure_ascii=False))],
                                    is_error=inv.status in _ERRORS)

    def get_schema(name: str):
        tool = registry.get(name)
        return tool.parameters if tool else None

    server = Server("mydata", version=__version__, instructions=(
        "Tools over the user's own data on this machine. Irreversible tools (such as send_mail) are held for "
        "the user's approval in myData and return an approval id; they do not run until the user approves."),
        get_tool_input_schema=get_schema, on_list_tools=on_list_tools, on_call_tool=on_call_tool)
    # The SDK leaves DNS-rebinding protection off for a hand-built manager; turn it on, for this machine only.
    security = TransportSecuritySettings(enable_dns_rebinding_protection=True, allowed_hosts=LOCAL_HOSTS,
                                         allowed_origins=LOCAL_ORIGINS)
    return StreamableHTTPSessionManager(app=server, security_settings=security)
