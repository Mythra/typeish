#!/usr/bin/env bash

# set -e intentionally off to validate defer guard
set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/../../../defer.sh"

messWithGlobalErrorMode() {
  set +e
  false
  echo "hey"
}

deferd() {
  defer_guard_errors

  echo "in_func"
  messWithGlobalErrorMode
  false
  echo "Won't be printed"
}

deferd