#!/usr/bin/env -S -- jq --exit-status --from-file

def envsub: gsub("[$]\\{(?<var>[A-Za-z_][A-Za-z0-9_]*)\\}"; "{env:\(.var)}");

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

.formatter._.extensions = ($m[0] | keys | unique) | .mcp = (($c[0].mcpServers // $c[0]) | map_values(xform))
