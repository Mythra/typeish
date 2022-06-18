#!/usr/bin/env bash

source "$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/logger.sh"

# A map type that is actually stored as an array of strings, but brings all
# the benefits of an associative array. Internally starts with a `__MAP_ID`
# in order to ensure that the type was previously created with these
# functions.
#
# Function names follow the format of `<operation>_map`, such as:
# `contains_map`.

# Allow `__MAP_ID` to be set to change.
if [ -z "${__MAP_ID+x}" ] ; then
  export __MAP_ID="__TYPED_MAP"
fi

# make_map(key_value_strings: Array<String>) -> Map
#
# Modifies Globals: None
#
# Takes in a list of key value pairs like: `key=value` in the form of args,
# (yes this supports `=` in the value portion), returning a map that can be
# used with other functions this file defines.
make_map() {
  local map_as_array=("$__MAP_ID")
  
  local arg=
  for arg in "$@" ; do
    map_as_array+=($arg)
  done

  printf "%s$IFS" "${map_as_array[@]}"
}
export -f make_map

# get_map(map: Map, key: String) -> String || error
#
# Modifies Globals: None
#
# Takes in a map, and a key to find in the map, returning the value for the
# associated key.
get_map() {
  local -r key_to_read="$2"
  local -r map_as_array=($(printf '%s' "$1"))

  local pair=
  local is_first=0
  for pair in "${map_as_array[@]}"; do
    if [ "$is_first" -eq "0" ]; then
      if [ "$pair" != "$__MAP_ID" ]; then
        log:error "get_map got called with a non-map type"
        return 1
      fi
      is_first=1
      continue
    fi

    if [ "${pair%%=*}" = "$key_to_read" ]; then
      printf '%s' "${pair#*=}"
      return 0
    fi
  done

  return 1
}
export -f get_map

# get_default_map(map: Map, key: String, default: String) -> String
#
# Modifies Globals: None
#
# Takes in a map, and a key to find in the map, returning the value for the
# associated key, or the default provided value.
get_default_map() {
  get_map "$1" "$2" || {
    printf '%s' "$3"
    return 0
  }
}
export -f get_default_map

# contains_map(map: Map, key: String) -> boolean
#
# Modifies Globals: None
#
# Takes in a map, and a key to find in the map. Returning if the key is in the
# map.
contains_map() {
  get_map "$1" "$2" >/dev/null 2>&1 && return 0 || return 1
}
export -f contains_map

# upsert_map(map: Map, new_pair: String) -> Map || error code
#
# Modifies Globals: None
#
# Takes in a map, and a new value pair. This key can already exist, and it'll
# update the item in the map. If not it will insert the item into the map.
upsert_map() {
  local -r new_pair="$2"
  local -r upsert_key="${new_pair%%=*}"
  local new_map=("$__MAP_ID")
  local -r map_as_array=($(printf '%s' "$1"))

  local is_first=0
  local did_update=0
  local pair=""
  for pair in "${map_as_array[@]}"; do
    if [ "$is_first" -eq "0" ]; then
      if [ "$pair" != "$__MAP_ID" ]; then
        log:error "upsert_map got called with a non-map type first was: $pair"
        return 1
      fi
      is_first=1
      continue
    fi

    if [ "${pair%%=*}" != "$upsert_key" ]; then
      new_map+=("$pair")
    else
      did_update=1
      new_map+=("$new_pair")
    fi
  done

  if [ "$did_update" -eq "0" ]; then
    new_map+=("$new_pair")
  fi

  printf "%s$IFS" "${new_map[@]}"
}
export -f upsert_map

# delete_map(map: Map, key: String) -> boolean
#
# Modifies Globals: None
#
# Takes in a map, and a key to find in the map, deleting if the map succeeds
# in deletion. Returning boolean if it was deleted, or failed.
delete_map() {
  local -r key_to_delete="$2"
  local -r map_as_array=($(printf '%s' "$1"))
  local new_map=("$__MAP_ID")

  local pair=
  local is_first=0
  for pair in "${map_as_array[@]}"; do
    if [ "$is_first" -eq "0" ]; then
      if [ "$pair" != "$__MAP_ID" ]; then
        log:error "delete_map got called with a non-map type"
        return 1
      fi
      is_first=1
      continue
    fi

    if [ "${pair%%=*}" != "$key_to_delete" ]; then
      new_map+=("$pair")
    fi
  done

  printf "%s$IFS" "${new_map[@]}"
}
export -f delete_map

# is_empty_map(map: Map) -> boolean
#
# Modifies Globals: None
#
# Return if a map is empty or not.
is_empty_map() {
  local -r map_as_array=($(printf '%s' "$1"))
  if [ "${#map_as_array[@]}" -eq "1" ]; then
    return 0
  else
    return 1
  fi
}
export -f is_empty_map

# keys_map(map: Map) -> Array<String> || error code
#
# Modifies Globals: None
#
# Get the keys in a map.
keys_map() {
  local -r map_as_array=($(printf '%s' "$1"))
  local keys=()

  local pair=
  local is_first=0
  for pair in "${map_as_array[@]}"; do
    if [ "$is_first" -eq "0" ]; then
      if [ "$pair" != "$__MAP_ID" ]; then
        log:error "keys_map got called with a non-map type"
        return 1
      fi
      is_first=1
      continue
    fi

    keys+=("${pair%%=*}")
  done

  printf "%s$IFS" "${keys[@]}"
}
export -f keys_map

# values_map(map: Map) -> Array<String> || error code
#
# Modifies Globals: None
#
# Get the values of a map.
values_map() {
  local -r map_as_array=($(printf '%s' "$1"))
  local values=()

  local pair=
  local is_first=0
  for pair in "${map_as_array[@]}"; do
    if [ "$is_first" -eq "0" ]; then
      if [ "$pair" != "$__MAP_ID" ]; then
        log:error "values_map got called with a non-map type"
        return 1
      fi
      is_first=1
      continue
    fi

    values+=("${pair#*=}")
  done

  printf "%s$IFS" "${values[@]}"
}
export -f values_map

# size_map(map: Map) -> int
#
# Modifies Globals: None
#
# Get the size of a map
size_map() {
  local -r map_as_array=($(printf '%s' "$1"))
  local -r map_raw_size="${#map_as_array[@]}"
  echo $(( map_raw_size - 1 ))
}
export -f size_map