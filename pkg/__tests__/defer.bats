#!/usr/bin/env bats

@test "simple defer runs at the end" {
  run $BATS_TEST_DIRNAME/test-cases/defer/simple.sh
  [ "$status" -eq "0" ]
  [ "${#lines[@]}" = "2" ]
  [ "${lines[0]}" = "after" ]
  [ "${lines[1]}" = "defer'd" ]
}

@test "multi-defer" {
  run $BATS_TEST_DIRNAME/test-cases/defer/multi.sh
  [ "$status" -eq "0" ]
  [ "${#lines[@]}" = "3" ]
  [ "${lines[0]}" = "in_func" ]
  [ "${lines[1]}" = "after" ]
  [ "${lines[2]}" = "after.2" ]
}

@test "attempts to reject functions" {
  run $BATS_TEST_DIRNAME/test-cases/defer/nono-func.sh
  [ "$status" -eq "1" ]
  [ "${#lines[@]}" -eq "0" ]
}

@test "defer_guard_errors impacts defer'd statements" {
  run $BATS_TEST_DIRNAME/test-cases/defer/guard-impacts-defer.sh
  [ "$status" -eq "1" ]
  [ "${#lines[@]}" = "1" ]
  [ "${lines[0]}" = "in_func" ]
}

@test "defer can be source'd multiple times" {
  run $BATS_TEST_DIRNAME/test-cases/defer/multi-source.sh
  [ "$status" -eq "0" ]
  [ "${#lines[@]}" -eq "3" ]
  [ "${lines[0]}" = "in_func" ]
  [ "${lines[1]}" = "defer_pre" ]
  [ "${lines[2]}" = "defer_post" ]
}

@test "is resilient to err mode hijinks" {
  run $BATS_TEST_DIRNAME/test-cases/defer/err-mode-hijink.sh
  [ "$status" -eq "1" ]
  [ "${#lines[@]}" -eq "2" ]
  [ "${lines[0]}" = "in_func" ]
  [ "${lines[1]}" = "hey" ]
}