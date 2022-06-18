#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/../../../defer.sh"

uses_defer() {
  defer "echo after.2"
  defer "echo after"
  echo "in_func"
}
uses_defer