#!/usr/bin/env -S -- jq --exit-status --from-file

def leaf_paths:
  def walk($prefix):
    if type == "object" then
      to_entries[] as $entry | $entry.value | walk($prefix + [$entry.key])
    else
      $prefix
    end;
  walk([]);

def mcp_servers:
  to_entries | map(.key as $name | .value | del(.type, .alwaysLoad) | {key: $name, value: .}) | from_entries;

. * {mcp_servers: ($mcp | mcp_servers)}
| leaf_paths as $p
| "\($p | join("."))=\(getpath($p) | tojson)"
