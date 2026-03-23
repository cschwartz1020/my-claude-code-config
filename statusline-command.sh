#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract current working directory from JSON
cwd=$(echo "$input" | jq -r '.workspace.current_dir')

# Get username
user=$(whoami)

# Get model name
model=$(echo "$input" | jq -r '.model.display_name // "unknown"')

# Get current time
time=$(date +%H:%M:%S)

# Replace home directory with ~ for display
display_dir="${cwd/#$HOME/~}"

# Get git branch info
git_branch=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [[ -n "$branch" ]]; then
    git_branch=" ($branch)"
  fi
fi

# Context window visualization
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

# Compaction counter - detect when context drops significantly
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
state_file="/tmp/claude-compaction-${session_id}.state"

# Read previous state (max_pct:compaction_count)
if [[ -f "$state_file" ]]; then
  max_pct=$(cut -d: -f1 "$state_file")
  compaction_count=$(cut -d: -f2 "$state_file")
else
  max_pct=0
  compaction_count=0
fi

# Detect compaction: context dropped by 30%+ from the maximum (which was >60%)
# Note: /clear resets the counter via SessionStart hook (reset-compaction-counter.sh)
if [[ $max_pct -gt 60 && $((max_pct - ctx_pct)) -gt 30 ]]; then
  compaction_count=$((compaction_count + 1))
  # Reset max after detecting compaction
  max_pct=$ctx_pct
fi

# Update max if current is higher
if [[ $ctx_pct -gt $max_pct ]]; then
  max_pct=$ctx_pct
fi

# Save current state
echo "${max_pct}:${compaction_count}" > "$state_file"

bar_width=10
filled=$((ctx_pct * bar_width / 100))
empty=$((bar_width - filled))

# Compaction threshold - calculated from autocompact buffer if available
# Autocompact buffer is typically ~16.5% of context, so compaction happens at ~84%
autocompact_buffer_pct=$(echo "$input" | jq -r '.context_window.autocompact_buffer_percentage // 0' | cut -d. -f1)
if [[ $autocompact_buffer_pct -gt 0 ]]; then
  compaction_threshold=$((100 - autocompact_buffer_pct))
else
  # Fallback: buffer is typically 16.5%, so threshold is ~84%
  compaction_threshold=84
fi
compaction_pos=$((compaction_threshold * bar_width / 100))

# Color based on usage: green < 50%, yellow 50-80%, red > 80%
if [[ $ctx_pct -lt 50 ]]; then
  ctx_color="\033[32m"  # green
elif [[ $ctx_pct -lt 80 ]]; then
  ctx_color="\033[33m"  # yellow
else
  ctx_color="\033[31m"  # red
fi

# Build bar with red line at compaction point (overlaid on background)
bar=""
for ((i=0; i<bar_width; i++)); do
  if [[ $i -eq $compaction_pos ]]; then
    # Red thin vertical line overlaid on appropriate background
    if [[ $i -lt $filled ]]; then
      # On filled area: red line on colored background
      bar+="\033[31m▏\033[0m"
    else
      # On empty area: red line on gray background
      bar+="\033[31;100m▏\033[0m"
    fi
  elif [[ $i -lt $filled ]]; then
    bar+="${ctx_color}█\033[0m"
  else
    bar+="\033[100m \033[0m"
  fi
done

# Build the status line with colors matching your zsh PROMPT
# cyan for username, red for IP, yellow for time
# Compaction count indicator (always shown) - green when 0, red otherwise
if [[ $compaction_count -eq 0 ]]; then
  compact_indicator=" \033[32m${compaction_count}↻\033[0m"
else
  compact_indicator=" \033[31m${compaction_count}↻\033[0m"
fi

printf "\033[36m%s\033[0m & \033[35m%s\033[0m \033[33m[%s]\033[0m %s%s [%b %d%%]%b\n" "$user" "$model" "$time" "$display_dir" "$git_branch" "$bar" "$ctx_pct" "$compact_indicator"

# ============================================================
# Additional lines matching screenshot format
# ============================================================

RST="\033[0m"; GRN="\033[32m"; YLW="\033[33m"; RED="\033[31m"
CYN="\033[36m"; GRY="\033[90m"; ORG="\033[38;5;208m"

# Extract token counts from actual JSON fields
total_tokens=$(echo "$input" | jq -r '.context_window.context_window_size // 0')
remain_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // 0' | cut -d. -f1)
used_tokens=$((total_tokens * ctx_pct / 100))
remain_tokens=$((total_tokens - used_tokens))

# Format as Xk
fk() { echo "$(($1 / 1000))k"; }

# Thinking: not in JSON, default On for thinking-capable models
TC="$GRN"
think_text="On"

# Line 2: Model | Token counts | Used/Remaining detail | Thinking
printf "${ORG}%s${RST} | %s / %s | ${ctx_color}%d%% used %'d${RST} | ${CYN}%d%% remain %'d${RST} | thinking: ${TC}%s${RST}\n" \
  "$model" "$(fk "$used_tokens")" "$(fk "$total_tokens")" "$ctx_pct" "$used_tokens" "$remain_pct" "$remain_tokens" "$think_text"
