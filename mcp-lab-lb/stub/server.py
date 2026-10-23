"""Stub MCP server for Thread 04-B · Topic 4A · C0 step 4 — two replicas of it sit behind nginx (T5 C2).

Objective: give the load balancer something real to route to. Each replica answers MCP over stateless
Streamable HTTP, reports which replica served a call, and exposes /healthz for container and nginx health checks.
No auth here: T4B adds token validation to the real server.
"""

import os

from starlette.requests import Request
from starlette.responses import PlainTextResponse

from mcp.server.mcpserver import MCPServer
from mcp.server.transport_security import TransportSecuritySettings

# Set per container in docker-compose.yml.
REPLICA_ID = os.environ.get("REPLICA_ID", "unknown")
# Host header values this server accepts. Behind nginx the client-facing host is localhost:8001, and nginx forwards
# that Host unchanged; anything else gets HTTP 421 from the DNS-rebinding protection (T1 S115).
ALLOWED_HOSTS = [h.strip() for h in os.environ.get("MCP_ALLOWED_HOSTS", "localhost:8001").split(",") if h.strip()]

# The same server name on every replica, so clients see one logical server (T1 S55).
mcp = MCPServer(
    "news-mcp-stub",
    version="0.0.1",
    instructions="C0 stub server. One tool, which_replica, reports which replica handled the call.",
)


@mcp.tool()
def which_replica() -> str:
    """Return the id of the replica that handled this call, to show how the load balancer spreads calls."""
    return REPLICA_ID


@mcp.custom_route("/healthz", methods=["GET"])  # type: ignore[untyped-decorator]  # mcp 2.3.0 returns an unannotated decorator
async def healthz(request: Request) -> PlainTextResponse:
    """Liveness for the container healthcheck and nginx; MCP removed ping, so health is an HTTP concern (T1 S100)."""
    return PlainTextResponse("ok\n")


app = mcp.streamable_http_app(
    stateless_http=True,
    transport_security=TransportSecuritySettings(
        enable_dns_rebinding_protection=True,
        allowed_hosts=ALLOWED_HOSTS,
        allowed_origins=[],
    ),
    host="0.0.0.0",
)