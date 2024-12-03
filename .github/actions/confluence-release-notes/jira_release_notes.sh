#!/bin/bash

set -e
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function usage {
  echo "Usage: [fixVersion] [releaseDate: YYYY-MM-DD]"
  exit 1
}

function validate_input {
  if [ -z "$1" ] || [ -z "$2" ]; then
    usage
  fi
  if [[ ! "$2" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    usage
  fi
}

function main {
  local fixVersion=$1
  local releaseDate=$2
  echo "RELEASE_NAME=$fixVersion"
  JQL="fixVersion = $fixVersion"
  local jira_ticket_file=$(mktemp)
  $SCRIPT_DIR/jira_find_tickets.sh "$JQL" > $jira_ticket_file
  echo "*** JIRA Tickets ***"
  cat $jira_ticket_file
  local release_notes_file=$(mktemp)
  node $SCRIPT_DIR/generate_release_notes.js $jira_ticket_file $release_notes_file
  echo "*** Release Notes ***"
  cat $release_notes_file
  YEAR=$(echo $releaseDate | cut -d'-' -f1)
  DATE=$releaseDate
  local results_file=$(mktemp)
  bash $SCRIPT_DIR/confluence_create_release_page.sh "$YEAR" "$fixVersion" "$DATE" $release_notes_file > $results_file
  echo "*** Results ***"
  cat $results_file
  jq -r '"\(.["_links"].base)\(.["_links"].webui)"' $results_file
}

validate_input "$1" "$2"
main "$1" "$2"
exit $?