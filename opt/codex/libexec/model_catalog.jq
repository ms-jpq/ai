#!/usr/bin/env -S -- jq --exit-status --from-file

.data
| map(
    select((.id | test("/[*]$") or . == "*") | not)
    | {
        slug: .id,
        display_name: (.id | sub(".*/"; "")),
        base_instructions: "",
        description: ("LiteLLM model " + .id),
        context_window: (.max_input_tokens // 128000),
        supported_reasoning_levels: [],
        shell_type: "shell_command",
        visibility: "list",
        supported_in_api: true,
        priority: 0,
        supports_reasoning_summaries: false,
        support_verbosity: false,
        supports_parallel_tool_calls: true,
        experimental_supported_tools: [],
        truncation_policy: { mode: "tokens", limit: 10000 }
      }
  )
| sort_by(.slug)
| {
    "$schema": "https://developers.openai.com/codex/config-schema.json",
    models: .
  }
