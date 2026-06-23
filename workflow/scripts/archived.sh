#!/bin/bash

# Script Filter for the `cla` keyword — browse ARCHIVED conversations.
# So you can get one back without remembering its name.
#   ↩  restore (bring it back to the list + activate)
#   ⌥↩ peek the archived log without restoring (folder sessions only)
# Type to filter by name.

set -u
source "$(dirname "$0")/sessions.lib.sh"

QUERY="$1"
qsan="$(sanitize_name "$QUERY")"
now=$(date +%s)

{
  shown=0
  while IFS=$'\t' read -r ats aname akey; do
    [[ -z "$aname" ]] && continue
    [[ -n "$qsan" && "$aname" != *"$qsan"* ]] && continue
    badge=""; [[ -f "$ARCHIVE/session.$akey.folder" ]] && badge="📁 "
    sid="$(cat "$ARCHIVE/session.$akey" 2>/dev/null)"; idp="${sid:0:8}"
    jq -nc \
      --arg t "♻️ ${badge}${aname}" \
      --arg s "archived $(rel_age "$ats" "$now")  ·  ${idp:-?}  ·  ↩ restore · ⌥ peek log" \
      --arg arg "restore:$akey" --arg aarg "openarc:$akey" \
      '{title:$t, subtitle:$s, arg:$arg,
        mods:{ alt:{arg:$aarg, subtitle:"Peek the archived log (without restoring)"} }}'
    shown=$((shown + 1))
  done < <(list_archived)

  if [[ "$shown" -eq 0 ]]; then
    jq -nc --arg s "${qsan:+nothing archived matches \"$qsan\" — }use cls ⌘↩ or clr to archive a thread" \
      '{title:"No archived conversations", subtitle:$s, valid:false}'
  fi
} | jq -s '{items: .}'
