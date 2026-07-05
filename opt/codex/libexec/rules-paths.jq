#!/usr/bin/env -S -- jq --exit-status --from-file

if .tool_name == "apply_patch" then
  (.tool_input.command | scan("(?m)^\\*\\*\\* (?:Add|Update|Delete) File: (.+)$")[]),
  (.tool_input.command | scan("(?m)^\\*\\*\\* Move to: (.+)$")[])
else
  empty
end
