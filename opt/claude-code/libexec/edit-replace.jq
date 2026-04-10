#!/usr/bin/env -S -- jq --exit-status --from-file

.tool_input as {old_string: $old, new_string: $new, replace_all: $all}
| ($original | split($old)) as $parts
| if ($parts | length) < 2 then $original
elif $all then $parts | join($new)
else $parts[0] + $new + ($parts[1:] | join($old))
end
