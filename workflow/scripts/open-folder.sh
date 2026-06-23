#!/bin/bash

# Run Script action for the `clf` keyword — open/resume a FOLDER-ANCHORED session.
#
#   clf <folder path>
#
# Anchors a Claude thread to <folder>: Claude runs there (cwd = file-tool root),
# and the transcript is routed to <folder>/claude-session.md. The top of that log
# carries the resume info (session id + commands), so you can later drop back into
# the folder and pick the conversation up — it's the source of truth, not the
# Alfred cache. After `clf`, ask as usual with `cl <question>`.
#
# Workflow: make a folder, drop in documents for context, `clf <that folder>`,
# then `cl …`. A fresh session started in the folder can also read the log as
# context (it's just a file in cwd).

set -u
source "$(dirname "$0")/sessions.lib.sh"
# open_with (honors the OPEN_WITH Alfred config var) lives in sessions.lib.sh.

RAW="${1:-}"
if [[ -z "${RAW// /}" ]]; then echo "Usage: clf <folder path>"; exit 0; fi

# Expand a leading ~, create the folder if needed, resolve to an absolute path.
FOLDER="${RAW/#\~/$HOME}"
mkdir -p "$FOLDER" 2>/dev/null
FOLDER="$(cd "$FOLDER" 2>/dev/null && pwd)"
if [[ -z "$FOLDER" ]]; then echo "Can't open folder: $RAW"; exit 0; fi

# Thread name = sanitized folder basename. If that name is already taken by a
# DIFFERENT folder (or a non-folder thread), auto-suffix (acme → acme-2) so we
# never hijack another conversation's handle. Re-opening the SAME folder keeps
# its name (so it resumes rather than forks).
name="$(sanitize_name "$(basename "$FOLDER")")"
[[ -z "$name" ]] && name="folder"
if [[ -e "$(session_file "$name")" && "$(thread_folder "$name")" != "$FOLDER" ]]; then
  name="$(free_name "$name")"
fi

LOG="$FOLDER/$LOG_NAME"
SF="$(session_file "$name")"

printf '%s' "$FOLDER" > "$(folder_file "$name")"   # bind folder ↔ thread
# Title = the anchor path (the cls list adds its own 📁 badge for folder threads).
[[ -s "$(title_file "$name")" ]] || printf '%s' "$FOLDER" > "$(title_file "$name")"
# Register the thread now (empty = no id yet → fresh start on first ask) so it
# shows up in `cls` immediately, before you've asked anything.
touch "$SF"
set_active_thread "$name"

if [[ -f "$LOG" ]]; then
  # Existing log: adopt its session id (folder is authoritative) and resume.
  sid="$(grep -m1 '^id:' "$LOG" | sed 's/^id:[[:space:]]*//')"
  [[ -n "$sid" && "$sid" != "PENDING" ]] && printf '%s' "$sid" > "$SF"
  open_with "$LOG"
  echo "▶ Resumed folder session '$name' — $FOLDER"
  exit 0
fi

# New folder session: write the resume header now; the id fills in on first `cl`.
{
  printf '<!--\nclaude-session\nid: PENDING\nfolder: %s\nresume (terminal): cd "%s" && claude --resume <id>\nresume (alfred):   clf "%s"\nstarted: %s\n-->\n\n' \
    "$FOLDER" "$FOLDER" "$FOLDER" "$(ts_now)"
  printf '# 💬 Claude session — %s\n\n' "$name"
} > "$LOG"
open_with "$LOG"
echo "✦ New folder session '$name' — ask with: cl <question>"
