#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}/../../typeish.sh"

sig { split.params { to_split: string, split_by: string }.returns{ array[string] }}
split() {
  local -r ORIGINAL_IFS="$IFS"
  # use a subshell for the lowest overhead + safe IFS reset.
  ( \
    IFS="$split_by" && \
    read -a split_text <<< "$to_split" && \
    printf "%s${ORIGINAL_IFS}" "${split_text[@]}" \
  )
}

sig_custom_type { forced_start.from { string }.produces { ForcedStartTy } }
forced_start() {
  case "$1" in
    "["*)
      return 0
      ;;
    *)
      log:error "String: \`$1\` does not start with '[', not valid."
      return 1
      ;;
  esac
}

sig_custom_type { forced_str_end.from { string }.produces { ForcedEndTy } }
forced_str_end() {
  case "$1" in
    *"]")
      return 0
      ;;
    *)
      log:error "String: \`$1\` does not end with ']', not valid."
      return 1
      ;;
  esac
}

sig_custom_type { forced_end.from { ForcedStartTy }.produces { ForcedStartEndStrTy } }
forced_end() {
  case "$1" in
    *"]")
      return 0
      ;;
    *)
      log:error "ForcedStarTy: \`$1\` does not end with ']', not valid."
      return 1
      ;;
  esac
}

# CustomTy is just an easier way of writing "ForcedStartEndStrTy"
sig_custom_type { type_fn.from { ForcedStartEndStrTy }.produces { CustomTy } }
type_fn() {
  return 0
}

sig { does_start_with_map_id.params {to_test: string}.returns{ void } }
does_start_with_map_id() {
  case "${to_test}" in
    "$__MAP_ID"*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

sig_custom_type { map_ty.from { string }.produces { Map_generic } }
map_ty() {
  log:trace "inside map_ty"
  # Check map starts with __MAP_ID
  if ! does_start_with_map_id "$1"; then
    log:error "Type isn't actually a valid map!"
    return 1
  fi
  if [ "x${2+x}" == "x" ]; then
    # No generic types on this map exit early.
    log:warn "Map called with no generic types -- which were expected."
    return 0
  fi
  local -r generic_types=($(split "$2" "-"))
  
  # Validate keys!
  if [ "x${generic_types[0]}" != "x" ]; then
    log:trace "Validating map key type against type: ${generic_types[0]}"
    local keys=($(keys_map "$1"))
    local key=
    for key in "${keys[@]}"; do
      if ! sig_validate_type_for "${generic_types[0]}" "${key}"; then
        log:error "Key of map: \`${key}\` was not valid for type: ${generic_types[0]}"
        return 1
      fi
    done
  fi
  # Validate values!
  if [ "x${generic_types[1]}" != "x" ]; then
    log:trace "Validating map value type against type: ${generic_types[1]}"
    local values=($(values_map "$1"))
    local value=
    for value in "${values[@]}"; do
      if ! sig_validate_type_for "${generic_types[1]}" "${value}"; then
        log:error "Value of map: \`${value}\` was not valid for type: ${generic_types[1]}"
        return 1
      fi
    done
  fi

  # We all good!
  return 0
}

sig { accepts_map.params { data: Map[string-ForcedStartEndStrTy] }.returns { string } }
accepts_map() {
  get_map "${data}" "key"
}

sig_update_functions

my_map=$(make_map "key=[my_cool_value]" "new_key=[ohnoooo")
accepts_map "${my_map}" && echo "Succeeded to get with bad data?" || echo "Properly failed accepts map!"
my_map=$(upsert_map  "${my_map}" "new_key=[ohyeah]")
accepts_map "${my_map}" && echo "Succeeded with new data!" || echo "Doesn't properly accept map :("
