#!/usr/bin/env bats

@test "logger can log at specific levels, and formats" {
  run $BATS_TEST_DIRNAME/test-cases/logger/log-levels.sh
  [ "$status" -eq "0" ]
  [ "${#lines[@]}" -eq "9" ]
  [ "${lines[0]}" = "info" ]
  [ "${lines[1]}" = "warn" ]
  [ "${lines[2]}" = "error" ]
  [ "${lines[3]}" = "trace" ]
  [ "${lines[4]}" = "debug" ]
  [ "${lines[5]}" = "info" ]
  [ "${lines[6]}" = "warn" ]
  [ "${lines[7]}" = "error" ]
  [ "${lines[8]}" = "error" ]
}