#!/usr/bin/env -S -- jq --exit-status --from-file

.data
| map(
    select((.id | test("/[*]$") or . == "*") | not)
    | {
        apply_patch_tool_type: "freeform",
        base_instructions: "",
        experimental_supported_tools: [],
        priority: 0,
        shell_type: "default",
        support_verbosity: false,
        supported_in_api: true,
        supported_reasoning_levels: [],
        supports_parallel_tool_calls: true,
        supports_reasoning_summaries: false,
        visibility: "list",

        context_window: (.max_input_tokens // 128000),
        description: .id,
        display_name: (.id | sub(".*/"; "")),
        slug: .id,
        truncation_policy: { mode: "tokens", limit: 10000 },
      }
  )
| sort_by(.slug)
| { models: .  }
