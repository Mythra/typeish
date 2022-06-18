#!/usr/bin/env bats

@test "empty map validation" {
  run $BATS_TEST_DIRNAME/test-cases/map/empty-map.sh
  [ "$status" -eq "0" ]
  [ "${#lines[@]}" -eq "7" ]
  [ "${lines[0]}" = "Could not find 'key'" ]
  [ "${lines[1]}" = "default" ]
  [ "${lines[2]}" = "Does not contain 'key'" ]
  [ "${lines[3]}" = "Map is empty" ]
  [ "${lines[6]}" = "Size: 0" ]
}

@test "non-empty map" {
  run $BATS_TEST_DIRNAME/test-cases/map/non-empty-map.sh
  [ "$status" -eq "0" ]
  [ "${#lines[@]}" -eq "18" ]
  [ "${lines[0]}" = "value" ]
  [ "${lines[1]}" = "value" ]
  [ "${lines[2]}" = "default" ]
  [ "${lines[3]}" = "Contains 'key'" ]
  [ "${lines[4]}" = "Does not contain 'key4'" ]
  [ "${lines[5]}" = "new_value" ]
  [ "${lines[6]}" = "value4" ]
  [ "${lines[7]}" = "default" ]
  [ "${lines[8]}" = "not-empty" ]
  [ "${lines[17]}" = "Size: 3" ]
}