#!/usr/bin/env -S -- jq --exit-status --from-file

.tool_input as {old_string: $old, new_string: $new, replace_all: $all}
| if $all
then $original | split($old) | join($new)
else
  ($original | index($old)) as $i
  | if $i
  then $original[:$i] + $new + $original[($i + ($old | length)):]
  else $original
  end
end
