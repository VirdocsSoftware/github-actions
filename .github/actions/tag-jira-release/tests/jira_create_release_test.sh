#!/bin/bash

CMD=$1

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function assert() {
  if [ "$1" != "$2" ]; then
    echo "Expected: $1"
    echo "Actual:   $2"
    exit 1
  else
    echo "OK"
  fi
}

function beforeAll() {
  unset JIRA_CONFIG
  unset JIRA_API_TOKEN
  unset JIRA_USERNAME
  unset JIRA_DOMAIN
  export CURL_PATH="$SCRIPT_DIR/mock_cmd.sh"
  export DATE_PATH="$SCRIPT_DIR/mock_cmd.sh"

}

function beforeEach() {
  export MOCK_ARGUMENT_FILE=$(mktemp)
  export MOCK_TRACKING_FILE=$(mktemp)
}

beforeAll

echo "Scenario: Create a release in Jira"
beforeEach

# GIVEN

export JIRA_CONFIG='{"auth": {"user":"user","token":"token"},"jira": {"domain": "company"}}'
export MOCK_RESPONSES='[{"stdout": "{\"id\":1234}"},{"stdout":"{\"values\":[]}"},{"stdout":"5"},{"stdout":"2023-04-04"}, {"stdout": "SUCCESS"}]'
export RELEASE_DATE="2023-04-04"
export JIRA_PROJECT="BILL"

# WHEN

ACTUAL_RESPONSE="$($CMD "v1.2.3" "Release description" )"

# THEN

assert "SUCCESS" "$ACTUAL_RESPONSE"
assert "-X GET -H Accept: application/json -u user:token https://company.atlassian.net/rest/api/3/project/BILL
-X GET -H Accept: application/json -u user:token https://company.atlassian.net/rest/api/3/project/BILL/version?query=v1.2.3
+%u
-d +11 days +%Y-%m-%d
--request POST --url https://company.atlassian.net/rest/api/3/version -u user:token --header Accept: application/json --header Content-Type: application/json --data {
    \"archived\": false,
    \"name\": \"v1.2.3\",
    \"description\": \"Release description\",
    \"projectId\": 1234,
    \"released\": false,
    \"releaseDate\": \"2023-04-04\"
  }" "$(cat $MOCK_ARGUMENT_FILE)"

echo "Scenario: Release already exists"
beforeEach

# GIVEN

export JIRA_CONFIG='{"auth": {"user":"user","token":"token"}}'
export MOCK_RESPONSES='[{"stdout": "{\"id\":1234}"},{"stdout":"{\"values\":[{\"name\":\"repo-v1.2.3\"}]}"},{"stdout":"5"},{"stdout":"2023-04-04"}, {"stdout": "SUCCESS"}]'
export RELEASE_DATE="2023-04-04"

# WHEN

ACTUAL_RESPONSE="$($CMD "repo-v1.2.3" "Release description" )"

# THEN

assert "Release repo-v1.2.3 already exists" "$ACTUAL_RESPONSE"

echo "Scenario: Update the description of an existing release"
beforeEach

# GIVEN

export JIRA_CONFIG='{"auth": {"user":"user","token":"token"},"jira": {"domain": "company"}}'
export UPDATE_DESCRIPTION="true"
export MOCK_RESPONSES='[
{"stdout": "{\"id\":1234}"},
{"stdout":"{\"values\":[{\"name\":\"repo-v1.2.3\"}]}"}
,{"stdout":"5"},
{"stdout":"4"},
{"stdout":"2024-10-04"},
{"stdout": "{\"status\":\"200\",\"content\":\"SUCCESS\"}200"}
]'
export RELEASE_DATE="2023-04-04"

# WHEN

ACTUAL_RESPONSE="$($CMD "repo-v1.2.3" "New Release description" )"

# THEN

assert "Updating the description of release repo-v1.2.3
Response Body: {\"status\":\"200\",\"content\":\"SUCCESS\"}
HTTP Status Code: 200" "$ACTUAL_RESPONSE"
assert '-X GET -H Accept: application/json -u user:token https://company.atlassian.net/rest/api/3/project/BILL
-X GET -H Accept: application/json -u user:token https://company.atlassian.net/rest/api/3/project/BILL/version?query=repo-v1.2.3
-X GET -H Accept: application/json -u user:token https://company.atlassian.net/rest/api/3/project/BILL/version?query=repo-v1.2.3
+%u
-d +12 days +%Y-%m-%d
-s -o /dev/fd/63 -w %{http_code} -X PUT -H Accept: application/json -H Content-Type: application/json -u user:token https://company.atlassian.net/rest/api/3/version/ -d {
  "archived": false,
  "name": "repo-v1.2.3",
  "description": "New Release description",
  "projectId": 1234,
  "released": "false",
  "releaseDate": "2024-10-04"
}' "$(cat $MOCK_ARGUMENT_FILE)"