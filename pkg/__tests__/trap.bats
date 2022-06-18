#!/usr/bin/env bats

@test "append_to_trap can add to an empty trap" {
  run $BATS_TEST_DIRNAME/test-cases/trap/add-empty.sh
  [ "$status" -eq "0" ]
  [ "${lines[0]}" = "onTrap" ]
  [ "${#lines[@]}" = "1" ]
}

@test "append_to_trap can add to an empty trap multiple times" {
  run $BATS_TEST_DIRNAME/test-cases/trap/add-multiple.sh
  [ "$status" -eq "0" ]
  [ "${lines[0]}" = "onTrap" ]
  [ "${lines[1]}" = "onTrap" ]
  [ "${lines[2]}" = "onTrap" ]
  [ "${#lines[@]}" = "3" ]
}

@test "current_trap_handler can print out a trap" {
  run $BATS_TEST_DIRNAME/test-cases/trap/get-text.sh
  [ "$status" -eq "0" ]
  [ "${lines[0]}" = "onTrap;onTrap;onTrap" ]
}

@test "current_trap_handler can print out a quoted trap" {
  run $BATS_TEST_DIRNAME/test-cases/trap/get-quoted-text.sh
  [ "$status" -eq "0" ]
  [ "${lines[0]}" = "echo 'hey \"hello\" \\\"sup\\\"'" ]
}