#!/usr/bin/env -S -- jq --exit-status --from-file

def envsub: gsub("[$]\\{MCP_DOMAIN\\}"; "{env:MCP_DOMAIN}");

def xform:
  if (.command // null) then
    {
      type: "local",
      command: ([.command] + (.args // [])),
      environment: (.env // {})
    }
  else
    {
      type: "remote",
      url: (.url | envsub),
      headers: (.headers // {})
    }
  end
  | .enabled = true;

.formatter.fmt.extensions = ($m[0] | keys | unique) | .mcp = (($c[0].mcpServers // $c[0]) | map_values(xform))
