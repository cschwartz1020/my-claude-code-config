# my-claude-code-config

Global Claude Code configuration. Contains `settings.json` and the status line script.

## Setup on a new machine

1. **Clone the repo** somewhere stable (the path gets hardcoded):
   ```bash
   git clone <repo-url> ~/git/my-claude-code-config
   ```

2. **Make the status line script executable:**
   ```bash
   chmod +x ~/git/my-claude-code-config/statusline-command.sh
   ```

3. **Copy settings to `~/.claude/settings.json`**, substituting your actual clone path:
   ```bash
   sed "s|/Users/charlieschwartz/git/my-claude-code-config|$HOME/git/my-claude-code-config|g" \
     ~/git/my-claude-code-config/settings.json > ~/.claude/settings.json
   ```
   Or edit `~/.claude/settings.json` manually and paste in the contents of `settings.json`, updating the `statusLine.command` path to match where you cloned the repo.

4. **Verify** by starting Claude Code — the status line should show username, model, time, directory, git branch, and a context window bar.

## What's in settings.json

- **Permissions**: pre-allowed git, gh, kubectl, AWS CLI, terraform, uv/python, make, and common shell commands
- **statusLine**: custom status bar showing user, model, time, cwd+branch, context window usage, and compaction count
- **effortLevel**: `high`
- **voiceEnabled**: `true`

## Status line

`statusline-command.sh` displays two lines:

1. `user & model [HH:MM:SS] ~/path (branch) [████░░░░░░ 42%] 0↻`
2. `model | 42k / 200k | 42% used 84000 | 58% remain 116000 | thinking: On`

The compaction counter (`↻`) tracks how many times the context has been auto-compacted in the session (green = 0, red = N).
