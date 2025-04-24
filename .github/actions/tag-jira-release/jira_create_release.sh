#!/bin/bash

if [ "$1" == "" ] || [ "$2" == "" ]; then
  echo "Usage: [release version] [description]"
  echo "  release version: the name of the release version to create"
  echo "  release description: A description of the release"
  exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TOKEN=$JIRA_TOKEN
USERNAME=$JIRA_EMAIL

if [ "$JIRA_URL" == "" ]; then
  JIRA_URL="https://$JIRA_DOMAIN/rest/api/3"
fi

if [ "$JIRA_PROJECT" == "" ]; then
  echo "No JIRA_PROJECT found"
  exit 1
fi

if [ "$RELEASE_DAY" == "" ]; then
  # Monday is 1, Sunday is 7
  RELEASE_DAY="2"
fi

if [ "$CURL_PATH" == "" ]; then
  CURL_PATH="$(which curl)"
fi

if [ "$DATE_PATH" == "" ]; then
  DATE_PATH="$(which date)"
fi

function next_release_date() {
  target_day=$1

  # Get the current day of the week (0-6)
  current_day=$($DATE_PATH +%u)

  # Calculate days until next target day
  if [ "$current_day" -eq 5 ]; then
      # If today is Friday, set release to Monday (3 days later)
      days_until_target_day=$(( 3 ))
  elif [ "$current_day" -ge 6 ]; then
      # If today is Saturday (6) or Sunday (0), set release to Monday
      days_until_target_day=$(( (8 - $current_day) % 7 ))
  else
      # Otherwise, release the next day
      days_until_target_day=1
  fi

  # Get the date of next target day in YYYY-MM-DD format
  next_target_day=$($DATE_PATH -d "+${days_until_target_day} days" +%Y-%m-%d 2>/dev/null)
  if [ "$?" != "0" ]; then
    next_target_day=$($DATE_PATH -v+${days_until_target_day}d +%Y-%m-%d 2>/dev/null)
  fi

  # Print the result
  echo $next_target_day
}

function create_payload() {
  local release="$1"
  local description="$2"
  
  # Escape new lines and double quotes for JSON compatibility
  local escaped_description=$(echo "$description" | sed ':a;N;$!ba;s/\n/ /g' | sed 's/"/\\"/g')
  
  local projectId="$3"
  local payload='{
    "archived": false,
    "name": "'$release'",
    "description": "'$escaped_description'",
    "projectId": '$projectId',
    "released": false,
    "releaseDate": "'$(next_release_date "$RELEASE_DAY")'"
  }'
  echo "$payload"
}

function get_project_by_key (){
  local url="$JIRA_URL/project/$1"
  response="$($CURL_PATH -X GET -H "Accept: application/json" -u "$USERNAME:$TOKEN" "$url")"
  echo "$response"
}

function create_release() {
  local release="$1"
  local description="$2"
  local payload="$(create_payload "$release" "$description" "$3")"
  local url="$JIRA_URL"
  headers='{
    "Accept": "application/json",
    "Content-Type": "application/json"
  }'
  
  $CURL_PATH --request POST \
  --url "https://$JIRA_DOMAIN/rest/api/3/version" \
  -u "$USERNAME:$TOKEN" \
  --header 'Accept: application/json' \
  --header 'Content-Type: application/json' \
  --data ''"$payload"''

  echo "$response"
}

function update_release() {
  local release="$1"
  local description="$2"
  local projectId="$3"
  local release_id="$(existing_release "$release" | jq -r .id)"
  
  # Constructing JSON payload using jq for safety
  local payload=$(jq --null-input \
    --arg name "$release" \
    --arg description "$description" \
    --argjson projectId "$projectId" \
    --arg released "false" \
    --argjson archived "false" \
    --arg releaseDate "$(next_release_date "$RELEASE_DAY")" \
    '{
      archived: $archived,
      name: $name,
      description: $description,
      projectId: $projectId,
      released: $released,
      releaseDate: $releaseDate
    }')

  local url="$JIRA_URL/version/$release_id"

  # Use curl to get both response body and status code
  local response_body
  local http_status

  # Execute curl and capture both response body and status code
  response_body=$($CURL_PATH -s -o >(cat) -w "%{http_code}" -X PUT -H "Accept: application/json" -H "Content-Type: application/json" -u "$USERNAME:$TOKEN" "$url" -d "$payload")
  
  # Extracting HTTP status code from the end of response_body
  http_status="${response_body:(-3)}"
  
  # Removing HTTP status code from response_body
  response_body="${response_body%$http_status}"

  # Return or print both values as needed
  echo "Response Body: $response_body"
  echo "HTTP Status Code: $http_status"

  # Optionally, return just the status code if that's all you need:
  if [ "$http_status" -ne 200 ]; then
    echo "Failed to update release $release"
    exit 1
  fi
  return 0
}

function get_versions() {
  response=$($CURL_PATH -X GET -H "Accept: application/json" -u "$USERNAME:$TOKEN" "$JIRA_URL/project/${JIRA_PROJECT}/version?query=$1")

  echo "$response" | jq '.values'
}

function existing_release() {
  local release="$1"
  local versions="$(get_versions $release)"
  local existing_release="$(echo "$versions" | jq -r '.[] | select(.name == "'$release'")')"
  echo "$existing_release"
}

PROJECT_ID="$(get_project_by_key "$JIRA_PROJECT" | jq -r .id)"

if [ "$(existing_release "$1")" != "" ]; then
  echo "Release $1 already exists"
  update_release "$1" "$2" "$PROJECT_ID"
else
  create_release "$1" "$2" "$PROJECT_ID"
fi
