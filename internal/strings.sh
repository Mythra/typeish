#!/usr/bin/env bash

# __typeish_str_split(to_split: string, split_by: string) -> Array<String>
#
# Modifies Globals: None
#
# Split a string on a specific value.
__typeish_str_split() {
  defer_guard_errors

  local -r to_split="$1"
  local -r split_by="$2"

  local -r ORIGINAL_IFS="$IFS"
  # use a subshell for the lowest overhead + safe IFS reset.
  ( \
    IFS="$split_by" && \
    read -a split_text <<< "$to_split" && \
    printf "%s${ORIGINAL_IFS}" "${split_text[@]}" \
  )
}