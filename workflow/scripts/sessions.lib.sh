#!/bin/bash

# Shared helpers for named Claude conversations ("threads").
#
# Data model, all under $STORE:
#   active                 - name of the currently active thread (default "current")
#   session.<name>         - Claude session id for <name>; mtime = last activity
#   session.<name>.title   - human title (first prompt snippet) for nicer lists
#   session.<name>.folder  - folder a thread is anchored to (folder sessions)
#   archive/               - archived session.<name>* files (off the main list)
#
# Sourced by every action script: ask.sh, sessions.sh, archived.sh,
# session-action.sh, clear-thread.sh, open-folder.sh, open-session-file.sh.

# Where thread state lives. Durable by design: Alfred's persistent workflow DATA
# dir, NOT the volatile cache (which the OS can purge). Override with the
# STORE_DIR config var — point it at a synced folder to share threads across
# machines. (Caveat: the conversation transcripts that `--resume` reads live in
# ~/.claude, which is per-machine — so a synced store gives you the thread *list*
# + folder-session logs everywhere, but resuming a plain thread works only on the
# machine it was created.)
STORE="${STORE_DIR:-${alfred_workflow_data:-${TMPDIR:-/tmp}/alfred-claude-switchboard}}"
STORE="${STORE/#\~/$HOME}"
ARCHIVE="$STORE/archive"
ACTIVE_FILE="$STORE/active"
mkdir -p "$STORE" "$ARCHIVE"

# Default thread name when none has ever been chosen.
DEFAULT_THREAD="current"

# Echo the active thread name (falls back to the default).
active_thread() {
  local n=""
  [[ -s "$ACTIVE_FILE" ]] && n="$(cat "$ACTIVE_FILE")"
  printf '%s' "${n:-$DEFAULT_THREAD}"
}

# Set the active thread. Args: $1 - name (already sanitized).
set_active_thread() { printf '%s' "$1" > "$ACTIVE_FILE"; }

# Sanitize an arbitrary string into a safe thread name: lowercase, keep
# [a-z0-9_-], everything else becomes '-', collapse/trim dashes. Empty -> "".
sanitize_name() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -e 's/[^a-z0-9_-]/-/g' -e 's/-\{2,\}/-/g' -e 's/^-//' -e 's/-$//'
}

# Paths for a thread. Args: $1 - name.
session_file()  { printf '%s/session.%s' "$STORE" "$1"; }
title_file()    { printf '%s/session.%s.title' "$STORE" "$1"; }
# Sidecar holding the absolute folder a thread is anchored to (folder sessions).
folder_file()   { printf '%s/session.%s.folder' "$STORE" "$1"; }
# Echo a thread's anchored folder (empty if it isn't a folder session). $1 - name.
thread_folder() { cat "$(folder_file "$1")" 2>/dev/null; }

# Filename of the in-folder transcript / resume log for folder sessions.
LOG_NAME="claude-session.md"

# Default filename for the plain-thread sink when OUTPUT doesn't name a file.
DEFAULT_OUTPUT_FILE="claude-log.md"

# Resolve where PLAIN (non-folder) threads send their transcript. Prints a file
# path to append to, or "" to mean Scratchpad. Honors the OUTPUT config var:
#   "scratchpad" → Scratchpad ("")
#   ""           → a default file in the working dir (works for everyone, no deps)
#   <path>       → that file (any .md/.txt — Obsidian note, plain file, anywhere)
plain_sink() {
  local out="${OUTPUT:-}" wd="${WORKING_DIR:-$HOME}"
  wd="${wd/#\~/$HOME}"
  case "$out" in
    scratchpad|Scratchpad) printf '' ;;
    "") printf '%s/%s' "$wd" "$DEFAULT_OUTPUT_FILE" ;;
    *)  printf '%s' "${out/#\~/$HOME}" ;;
  esac
}

# Human-readable Pacific timestamp for question headers, e.g. 2026-06-23 14:30 PT.
# (Swap the format for POSIX seconds with: date +%s)
ts_now() { TZ='America/Los_Angeles' date '+%Y-%m-%d %H:%M PT'; }

# Open a path in the OPEN_WITH app (Alfred config), falling back to the system
# default handler if that's blank or the app fails. $1 - path.
open_with() {
  local app="${OPEN_WITH:-}"
  if [[ -n "$app" ]]; then open -a "$app" "$1" 2>/dev/null || open "$1"
  else open "$1"; fi
}

# Open a thread's "surface": its folder log for folder sessions, else the plain-
# thread sink (the OUTPUT file, or Scratchpad). $1 - thread name.
open_session_file() {
  local n="$1" folder="$(thread_folder "$1")"
  if [[ -n "$folder" && -f "$folder/$LOG_NAME" ]]; then open_with "$folder/$LOG_NAME"
  elif [[ -n "$folder" ]]; then open_with "$folder"
  else
    local sink="$(plain_sink)"
    if [[ -n "$sink" ]]; then open_with "$sink"; else open -a Scratchpad 2>/dev/null || true; fi
  fi
}

# Epoch mtime of a file (0 if missing). Args: $1 - path.
mtime_of() { stat -f %m "$1" 2>/dev/null || echo 0; }

# Compact relative age from an epoch mtime. Args: $1 - epoch, $2 - now epoch.
rel_age() {
  local then="$1" now="$2" d=$(( $2 - $1 ))
  (( d < 0 )) && d=0
  if   (( d < 60 ));    then printf 'just now'
  elif (( d < 3600 ));  then printf '%dm ago' $(( d / 60 ))
  elif (( d < 86400 )); then printf '%dh ago' $(( d / 3600 ))
  else                       printf '%dd ago' $(( d / 86400 ))
  fi
}

# List thread names, most-recently-active first (excludes archived).
# Prints one name per line.
list_threads() {
  local f name
  for f in "$STORE"/session.*; do
    [[ -e "$f" ]] || continue
    name="${f##*/session.}"
    # Thread names are sanitized to contain no dot, so any dotted name is a
    # sidecar (session.<name>.title / .folder / …) — skip it.
    case "$name" in *.*) continue ;; esac
    printf '%s\t%s\n' "$(mtime_of "$f")" "$name"
  done | sort -rn | cut -f2-
}

# Next free thread name from a base: base, base-2, base-3, … (file-naming style).
free_name() {
  local base="$1" n="$1" k=1
  while [[ -e "$(session_file "$n")" ]]; do k=$((k + 1)); n="${base}-${k}"; done
  printf '%s' "$n"
}

# Archive a thread's sidecars under a unique key so nothing is ever clobbered —
# even archiving the same name several times in the same second. The key token
# is dot-free (so <name> stays recoverable) but otherwise opaque; display age
# comes from the file mtime, not the token. $1 - name.
archive_thread() {
  local n="$1" ts base k=1
  ts="$(date +%s)"
  base="$ARCHIVE/session.$n.$ts"
  while [[ -e "$base" || -e "$base.title" || -e "$base.folder" ]]; do
    k=$((k + 1)); base="$ARCHIVE/session.$n.${ts}-$k"
  done
  [[ -e "$(session_file "$n")" ]] && mv -f "$(session_file "$n")" "$base"        2>/dev/null
  [[ -e "$(title_file "$n")"   ]] && mv -f "$(title_file "$n")"   "$base.title"  2>/dev/null
  [[ -e "$(folder_file "$n")"  ]] && mv -f "$(folder_file "$n")"  "$base.folder" 2>/dev/null
}

# List archived entries newest-first as "<mtime>\t<name>\t<name>.<token>" (the
# last field is the archive key used to restore). The token is dot-free; entries
# without a token (old un-timestamped format) are skipped.
list_archived() {
  local f bn rest name
  for f in "$ARCHIVE"/session.*; do
    [[ -e "$f" ]] || continue
    bn="${f##*/}"                       # session.<name>.<token>[.title|.folder]
    case "$bn" in *.title|*.folder) continue ;; esac
    rest="${bn#session.}"               # <name>.<token>
    case "$rest" in *.*) ;; *) continue ;; esac   # must carry a token (a dot)
    name="${rest%.*}"                   # strip the trailing .<token>
    printf '%s\t%s\t%s\n' "$(mtime_of "$f")" "$name" "$rest"
  done | sort -rn
}
