#!/bin/bash

# This script is used to mock the execution of a command.

if [ "$MOCK_ARGUMENT_FILE" == "" ]; then
  echo "Please set the MOCK_ARGUMENT_FILE environment variable"
  exit 1
fi

if [ "$MOCK_TRACKING_FILE" == "" ]; then
  echo "Please set the MOCK_TRACKING_FILE environment variable"
  exit 1
fi

if [ "$MOCK_RESPONSES" == "" ]; then
  echo "Please set the MOCK_RESPONSES environment variable"
  exit 1
fi

# read the file
function read_tracking_file() {
  MOCK_TRACKING=$(cat $MOCK_TRACKING_FILE)
}

read_tracking_file

if [ "$MOCK_TRACKING" == "" ]; then
  # create the file contents
  echo "{\"execution_count\": 0}" > $MOCK_TRACKING_FILE
  read_tracking_file
fi

# get the execution count
EXECUTION_COUNT=$(echo "$MOCK_TRACKING" | jq -r .execution_count)
if [ "$?" != "0" ]; then
  echo "Failed to get the execution count from the tracking file"
  exit 1
fi
# echo "MOCK_RESPONSES: $MOCK_RESPONSES" >&2
# get the response
MOCK_RESPONSE="$(echo "$MOCK_RESPONSES" | jq -r ".[$EXECUTION_COUNT] | .stdout")"
MOCK_STDERR="$(echo "$MOCK_RESPONSES" | jq -r ".[$EXECUTION_COUNT] | .stderr")"
EXIT_CODE="$(echo "$MOCK_RESPONSES" | jq -r ".[$EXECUTION_COUNT] | .exit")"
if [ "$EXIT_CODE" == "null" ]; then
  EXIT_CODE=0
fi

# increment the execution count
EXECUTION_COUNT=$((EXECUTION_COUNT + 1))

# modify the json
MOCK_TRACKING=$(echo $MOCK_TRACKING | jq ".execution_count = $EXECUTION_COUNT")

# write the file
echo $MOCK_TRACKING > $MOCK_TRACKING_FILE

echo "$@" >> $MOCK_ARGUMENT_FILE
# echo "ARGUMENTS: $@" >&2
if [ "$MOCK_RESPONSE" != "null" ]; then
  echo "$MOCK_RESPONSE"
fi
if [ "$MOCK_STDERR" != "null" ]; then
  echo "$MOCK_STDERR" >&2
fi
# echo "MOCK_RESPONSE: $MOCK_RESPONSE" >&2
# echo "EXIT_CODE: $EXIT_CODE" >&2
exit $EXIT_CODE
