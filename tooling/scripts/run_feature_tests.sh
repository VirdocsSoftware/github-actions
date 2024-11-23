#!/bin/bash

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

echo Feature: check release version

# WHEN
RESULT=$($SCRIPT_DIR/check_release_version.sh)

# THEN
echo "$RESULT"
assert_equals "0" "$?"

