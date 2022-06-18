#!/usr/bin/env bash

# set -e intentionally off to validate defer guard
set -uo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/../../../defer.sh"

deferd() {
  defer "echo 'hi'"
  defer "false"
  defer_guard_errors

  echo "in_func"
}

deferd