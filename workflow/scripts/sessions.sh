#!/bin/bash

# Script Filter for the `cls` keyword — the conversation switchboard.
#
# Lists Claude threads (most-recently-active first), marks the active one, and
# offers actions via modifier keys. Emits Alfred Script Filter JSON; the chosen
# item's `arg` is handled by session-action.sh.
#
#   ↩  (return) - make this thread active (next `cl` resumes it)
#   ⌥↩ (alt)    - open this thread live in a terminal (claude --resume)
#   ⌘↩ (cmd)    - archive this thread (off the list, recoverable)
#
# Type a name that doesn't exist to get a "＋ New thread" item.
#
# IMPORTANT: this Script Filter does its own filtering, so set the workflow's
# Script Filter to NOT have Alfred re-sort/-filter (leave "Alfred filters
# results" unchecked) — otherwise our recency order is lost.

set -u
source "$(dirname "$0")/sessions.lib.sh"

QUERY="$1"
MAX_VISIBLE=12

now=$(date +%s)
active="$(active_thread)"
qsan="$(sanitize_name "$QUERY")"

emit_item() {  # builds one compact JSON item from named vars via jq
  # $8/$9 (ctrl arg/subtitle) optional; default ctrl to the plain action.
  jq -nc \
    --arg title "$1" --arg sub "$2" --arg arg "$3" \
    --arg carg "$4" --arg csub "$5" --arg aarg "$6" --arg asub "$7" \
    --arg targ "${8:-$3}" --arg tsub "${9:-}" \
    '{title:$title, subtitle:$sub, arg:$arg,
      mods:{ cmd:{arg:$carg, subtitle:$csub},
             alt:{arg:$aarg, subtitle:$asub},
             ctrl:{arg:$targ, subtitle:$tsub} }}'
}

{
  matched_exact=0
  shown=0
  total=0

  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    total=$((total + 1))

    # Filter by typed query (substring, case-insensitive) when one is given.
    if [[ -n "$qsan" && "$name" != *"$qsan"* ]]; then continue; fi
    [[ "$name" == "$qsan" ]] && matched_exact=1

    (( shown >= MAX_VISIBLE )) && continue
    shown=$((shown + 1))

    sf="$(session_file "$name")"
    tf="$(title_file "$name")"
    age="$(rel_age "$(mtime_of "$sf")" "$now")"
    sid="$(cat "$sf" 2>/dev/null)"
    idp="${sid:0:8}"
    human="$(cat "$tf" 2>/dev/null)"
    [[ -z "$human" ]] && human="(no messages yet)"

    mark="○"; [[ "$name" == "$active" ]] && mark="●"
    folder="$(thread_folder "$name")"
    badge=""; [[ -n "$folder" ]] && badge="📁 "
    emit_item \
      "$mark $name" \
      "${badge}$human  ·  $age  ·  ${idp:-new}" \
      "use:$name" \
      "archive:$name"  "Archive '$name' (off the list, recoverable)" \
      "open:$name"     "Open '$name' live in Ghostty" \
      "openfile:$name" "Open '$name' file (folder log / Scratchpad)"
  done < <(list_threads)

  # Offer to create a new thread when the typed name doesn't already exist.
  if [[ -n "$qsan" && "$matched_exact" -eq 0 ]]; then
    emit_item \
      "＋ New thread: ${qsan}" \
      "Start a fresh conversation; your next 'cl' question goes here" \
      "new:${qsan}" \
      "new:${qsan}" "Start thread ${qsan}" \
      "new:${qsan}" "Start thread ${qsan}"
  fi

  # When filtering, also surface matching ARCHIVED threads with a Restore action.
  # (Only when a query is typed, so the default list stays clean.)
  if [[ -n "$qsan" ]]; then
    while IFS=$'\t' read -r ats aname akey; do
      [[ -z "$aname" ]] && continue
      [[ "$aname" == *"$qsan"* ]] || continue
      emit_item \
        "♻️ Restore: ${aname}" \
        "archived $(rel_age "$ats" "$now") — bring it back to the list" \
        "restore:${akey}" \
        "restore:${akey}" "Restore ${aname}" \
        "restore:${akey}" "Restore ${aname}"
    done < <(list_archived)
  fi

  # Empty-state hint.
  if [[ "$total" -eq 0 && -z "$qsan" ]]; then
    jq -nc '{title:"No conversations yet",
             subtitle:"Type a name to start one, or just ask with: cl <question>",
             valid:false}'
  fi
} | jq -s '{items: .}'
