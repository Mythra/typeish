#!/usr/bin/env bats

@test "signatures can be validated, and run" {
  run $BATS_TEST_DIRNAME/test-cases/signatures-simple.sh
  [ "$status" -eq "0" ]
  # 3 error lines 2 on stdout
  [ "${#lines[@]}" -eq "5" ]
  [ "${lines[3]}" = "Properly failed accepts map!" ]
  [ "${lines[4]}" = "[my_cool_value]Succeeded with new data!" ]
}