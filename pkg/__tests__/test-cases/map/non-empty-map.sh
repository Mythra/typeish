#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/../../../map.sh"

map=$(make_map "key=value" "key2=value2" "key3=value3")
echo "$(get_map "$map" "key")"
echo "$(get_default_map "$map" "key" "default")"
echo "$(get_default_map "$map" "key4" "default")"
contains_map "$map" "key" && echo "Contains 'key'" || echo "Does not contain 'key'"
contains_map "$map" "key4" && echo "Contains 'key4'" || echo "Does not contain 'key4'"
map=$(upsert_map "$map" "key4=value4")
map=$(upsert_map "$map" "key=new_value")
echo "$(get_map "$map" "key")"
echo "$(get_default_map "$map" "key4" "default")"
map=$(delete_map "$map" "key4")
echo "$(get_default_map "$map" "key4" "default")"
is_empty_map "$map" && echo "empty" || echo "not-empty"
echo -e "Keys:\n$(keys_map "$map")"
echo -e "Values:\n$(values_map "$map")"
echo "Size: $(size_map "$map")"