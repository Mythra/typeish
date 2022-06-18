#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/../../../map.sh"

# Create an empty map
map=$(make_map)
get_map "$map" "key" && echo "get_map succeeded?" || echo "Could not find 'key'"
echo "$(get_default_map "$map" "key" "default")"
contains_map "$map" "key" && echo "contains_map succeeded?" || echo "Does not contain 'key'"
is_empty_map "$map" && echo "Map is empty" || echo "Map is not empty"
echo "Keys: $(keys_map "$map")"
echo "Values: $(values_map "$map")"
echo "Size: $(size_map "$map")"
# Finally validate delete doesn't fail
map=$(delete_map "$map" "key")
