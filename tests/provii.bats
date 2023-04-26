setup() {
  load 'test_helper/bats-support/load'
  load 'test_helper/bats-assert/load'
  # ... the remaining setup is unchanged

  # get the containing directory of this file
  # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
  # as those will point to the bats executable's location or the preprocessed file respectively
  DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
  echo $DIR
  # make executables in src/ visible to PATH
  PATH="$DIR/../:$PATH"

}

@test 'assert_success() $status only' {
  run bash -c "provii"
  assert_success
}

@test 'assert_success() test only' {
  run bash -c "provii env"
  assert_success
}

@test "can run our script" {
  provii
}
