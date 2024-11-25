#!/bin/bash

CMD=$1

function assert_equals {
  if [ "$1" != "$2" ]; then
    echo "Expected: $1"
    echo "Actual:   $2"
    exit 1
  else
    echo "OK"
  fi
}

SCRIPT_DIR=$(cd $(dirname $0); pwd)

echo Scenario: Check the release version

# GIVEN

export MOCK_ARGUMENT_FILE=$(mktemp)
export MOCK_RESPONSES='[{"stdout":"release/v1.0.0"},{"stdout":"1.0.0"},{"stdout":"1.0.0"}]'
export MOCK_TRACKING_FILE=$(mktemp)
export GIT_PATH="$SCRIPT_DIR/mock_cmd.sh"
export JQ_PATH="$SCRIPT_DIR/mock_cmd.sh"
export FIGLET_PATH="$SCRIPT_DIR/mock_cmd.sh"
export EVENT="pull_request"
export TARGET_BRANCH="main"
export NEXT_PREDICTED_RELEASE="1.0.0"

# WHEN

ACTUAL_RESULT="$($CMD)"

# THEN

assert_equals "Everything is good.  Ready to release
1.0.0" "$ACTUAL_RESULT"
assert_equals "rev-parse --abbrev-ref HEAD
-r .version ./package.json
version 1.0.0" "$(cat $MOCK_ARGUMENT_FILE)"