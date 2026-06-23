#!/bin/bash

# Run Script action for the `cl` keyword — the "ask" command.
#
# Fire-and-forget: returns to Alfred immediately, runs Claude detached in the
# background, and appends the question + answer to this thread's output surface
# (a Markdown file, an Obsidian note, or Scratchpad — see OUTPUT / plain_sink).
#
# If the active thread is FOLDER-ANCHORED (created via clf), the transcript is
# routed to that folder's claude-session.md log instead, and Claude runs in that
# folder. See open-folder.sh.
#
# Conversation persistence: each invocation CONTINUES the active thread by
# resuming its stored session id. The active thread is chosen via the `cls`
# switchboard (sessions.sh); `clr` (clear-thread.sh) retires it. Default thread
# is "current".
#
# Config (exported by Alfred from userconfigurationconfig):
#   CLAUDE_CLI_PATH  - path to the claude binary   (default ~/.local/bin/claude)
#   MODEL            - model passed to --model      (default sonnet)
#   WORKING_DIR      - directory to run claude in   (default ~ (home))
#   OUTPUT           - where PLAIN threads log: blank → a default file in
#                      WORKING_DIR; "scratchpad" → Scratchpad; or any file path
#                      (any .md/.txt — an Obsidian note, plain file, anywhere).
#                      Folder sessions (clf) ignore this; they use their own log.
#   YOU_EMOJI        - the emoji marking your questions (default 🤔)

set -u

CLAUDE_CLI="${CLAUDE_CLI_PATH:-$HOME/.local/bin/claude}"
CLAUDE_MODEL="${MODEL:-sonnet}"
OUTPUT="${OUTPUT:-}"   # blank → plain_sink picks a default file in WORKING_DIR
YOU_EMOJI="${YOU_EMOJI:-🤔}"

# Directory Claude wakes up in. A project dir gives Claude rich context (and loads
# any CLAUDE.md there); a bare dir keeps quick asks light. Alfred passes config
# text literally, so expand a leading ~ ourselves.
WORKING_DIR="${WORKING_DIR:-$HOME}"
WORKING_DIR="${WORKING_DIR/#\~/$HOME}"

# Shared thread helpers (CACHE, active_thread, session_file, title_file, …).
source "$(dirname "$0")/sessions.lib.sh"
ERRLOG="$CACHE/ask.log"

PROMPT="$1"

# Resume whichever thread is active (set via cls / clr).
THREAD="$(active_thread)"
SESSION_FILE="$(session_file "$THREAD")"
TITLE_FILE="$(title_file "$THREAD")"

# Decide where this thread's transcript goes:
#   • folder-anchored thread (clf) → its own in-folder log; run Claude there.
#   • plain thread → per OUTPUT: Scratchpad, or append to a file (Obsidian note,
#     any .md). DEDICATED=1 marks a folder log (one thread per file → no thread
#     tag needed); a shared file/Scratchpad gets a [thread] tag on each question.
FOLDER="$(thread_folder "$THREAD")"
LOG_MD=""; DEDICATED=0
if [[ -n "$FOLDER" && -d "$FOLDER" ]]; then
  LOG_MD="$FOLDER/$LOG_NAME"; WORKING_DIR="$FOLDER"; DEDICATED=1
else
  LOG_MD="$(plain_sink)"                                     # "" = Scratchpad, else a file
  [[ -n "$LOG_MD" ]] && mkdir -p "$(dirname "$LOG_MD")" 2>/dev/null
fi
TS="$(ts_now)"

# --- helpers ---------------------------------------------------------------

# URL-encode an argument for the scratchpad: URL scheme (jq '@uri').
sp_encode() { jq -rn --arg s "$1" '$s|@uri'; }

# Append Markdown text to Scratchpad, bringing the window forward.
scratchpad_append() { open "scratchpad:append?text=$(sp_encode "$1")"; }

# Same, but leave the Scratchpad window hidden (used for the background answer
# so it doesn't steal focus while you're elsewhere — flip to scratchpad_append
# if you'd rather it pop forward when the answer arrives).
scratchpad_append_hidden() {
  open --background "scratchpad:append?text=$(sp_encode "$1")&hide"
}

# Post the (timestamped) question to wherever this thread routes output:
# the folder log file, or Scratchpad.
post_question() {
  # Tag the question with the thread name when it isn't the default, so parallel
  # threads are legible in a shared sink. A dedicated folder log is one thread
  # per file, so it needs no tag.
  local named=0
  [[ "$THREAD" != "$DEFAULT_THREAD" ]] && named=1
  if [[ -n "$LOG_MD" ]]; then
    local tag=""
    [[ "$named" -eq 1 && "$DEDICATED" -eq 0 ]] && tag=" · [${THREAD}]"
    printf '\n## %s %s%s\n%s\n' "$YOU_EMOJI" "$TS" "$tag" "$PROMPT" >> "$LOG_MD"
  else
    local tag=""
    [[ "$named" -eq 1 ]] && tag=" · _[${THREAD}]_"
    scratchpad_append "### ${YOU_EMOJI} You — _${TS}_${tag}
$PROMPT

_⏳ asking claude ($CLAUDE_MODEL)…_
"
  fi
}

# Re-level an answer's Markdown headings so its SHALLOWEST heading sits exactly
# one level below $2 (our wrapper level) — preserving the answer's internal
# hierarchy, never colliding with the wrapper, and shifting the minimum amount
# (so a normal "## …" answer becomes "### …", not "#### …"). Skips fenced code
# blocks; caps at h6; no-op if the answer has no headings or is already deep
# enough. $1 = text, $2 = wrapper heading level.
nest_headings() {
  printf '%s' "$1" | awk -v base="$2" '
    { line[NR] = $0 }
    /^[[:space:]]*(```|~~~)/ { f = !f; next }
    !f && /^#{1,6}[[:space:]]/ {
      n = 0; while (substr($0, n+1, 1) == "#") n++;
      if (min == 0 || n < min) min = n
    }
    END {
      add = (min > 0) ? (base + 1 - min) : 0; if (add < 0) add = 0
      for (i = 1; i <= NR; i++) {
        l = line[i]
        if (l ~ /^[[:space:]]*(```|~~~)/) { g = !g; print l; continue }
        if (!g && l ~ /^#{1,6}[[:space:]]/) {
          n = 0; while (substr(l, n+1, 1) == "#") n++;
          m = n + add; if (m > 6) m = 6;
          h = ""; for (j = 0; j < m; j++) h = h "#";
          print h substr(l, n+1)
        } else print l
      }
    }
  '
}

# Post a finished answer/error block. $1 = heading label (e.g. "Claude"),
# $2 = body markdown. In a folder log the answer is an h2 (folds independently of
# the h2 question), with its inner headings re-leveled to nest just beneath it.
post_answer() {
  if [[ -n "$LOG_MD" ]]; then
    printf '\n## 🤖 %s\n%s\n\n---\n' "$1" "$(nest_headings "$2" 2)" >> "$LOG_MD"
  else
    scratchpad_append_hidden "### 🤖 $1
$2

---
"
  fi
}

# --- guardrails ------------------------------------------------------------

if [[ -z "${PROMPT// /}" ]]; then
  echo "Usage: cl <your question>"
  exit 0
fi

if [[ ! -x "$CLAUDE_CLI" ]]; then
  scratchpad_append "## ⚠️ Claude CLI not found
\`$CLAUDE_CLI\` is missing or not executable. Set **Claude CLI Path** in the workflow config."
  echo "Claude CLI not found at $CLAUDE_CLI"
  exit 0
fi

# --- instant feedback ------------------------------------------------------

# Record the question right away. For Scratchpad this brings the window forward
# (immediate, persistent confirmation the ask is in flight); for a folder log it
# appends the question so it's visible the moment the editor reloads.
post_question

# --- detached job ----------------------------------------------------------

# Resume the stored session if we have one; otherwise start fresh and capture
# the new session id. The id is stable across resumes, so we store it once.
(
  trap '' HUP INT

  # Run from the configured directory so Claude's file tools land somewhere
  # useful; fall back to $HOME if it's gone.
  cd "$WORKING_DIR" 2>/dev/null || cd "$HOME"

  resume_id=""
  [[ -s "$SESSION_FILE" ]] && resume_id="$(cat "$SESSION_FILE")"

  if [[ -n "$resume_id" ]]; then
    raw=$("$CLAUDE_CLI" -p "$PROMPT" --model "$CLAUDE_MODEL" \
      --resume "$resume_id" --output-format json 2>>"$ERRLOG")
  else
    raw=$("$CLAUDE_CLI" -p "$PROMPT" --model "$CLAUDE_MODEL" \
      --output-format json 2>>"$ERRLOG")
  fi

  # Pull out the answer and the (possibly new) session id.
  answer=$(printf '%s' "$raw" | jq -r '.result // empty' 2>/dev/null)
  new_sid=$(printf '%s' "$raw" | jq -r '.session_id // empty' 2>/dev/null)
  is_err=$(printf '%s' "$raw" | jq -r '.is_error // false' 2>/dev/null)

  [[ -n "$new_sid" ]] && printf '%s' "$new_sid" >"$SESSION_FILE"
  # Cache a title (first prompt snippet) the first time this thread is used.
  [[ -s "$TITLE_FILE" ]] || printf '%s' "$PROMPT" | head -c 80 >"$TITLE_FILE"
  # Fill the resume id into the folder log header on the first ask — both the
  # `id:` line and the copy-pasteable terminal-resume command.
  if [[ -n "$LOG_MD" && -n "$new_sid" ]]; then
    sed -i '' -e "s|^id: PENDING|id: $new_sid|" -e "s|--resume <id>|--resume $new_sid|" "$LOG_MD" 2>/dev/null
  fi

  if [[ -z "$answer" || "$is_err" == "true" ]]; then
    post_answer "⚠️ Claude error" "\`\`\`
$(printf '%s' "$raw" | head -c 1500)
\`\`\`"
  else
    post_answer "Claude" "$answer"
  fi
) >/dev/null 2>&1 &

disown 2>/dev/null || true

# Return immediately so Alfred never blocks.
if [[ -n "$LOG_MD" ]]; then echo "Asked Claude → ${LOG_MD}"; else echo "Asked Claude → Scratchpad"; fi
exit 0
