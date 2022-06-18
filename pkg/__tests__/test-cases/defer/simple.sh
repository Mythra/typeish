#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/../../../defer.sh"

uses_defer() {
  defer "echo defer'd"
  echo "after"
}
uses_defer