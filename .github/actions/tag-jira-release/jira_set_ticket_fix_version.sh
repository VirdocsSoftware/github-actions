#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
TOKEN=$JIRA_TOKEN
USERNAME=$JIRA_EMAIL
TICKET_NUMBER="$1"
VERSION_NAME="$2"


function update_jira_ticket() {
  # Construct the Jira API URL for the ticket
  JIRA_API_URL="https://${JIRA_DOMAIN}/rest/api/2/issue/${TICKET_NUMBER}"

  # Construct the JSON payload for the update request
  JSON_PAYLOAD="{\"update\":{\"fixVersions\":[{\"add\":{\"name\":\"${VERSION_NAME}\"}}]}}"
  # Send the update request using curl
  $CURL_PATH --silent --request PUT --user "${USERNAME}:${TOKEN}" --header "Content-Type: application/json" --data "${JSON_PAYLOAD}" "${JIRA_API_URL}"
}

function existing_version() {
  $JIRA_GET_TICKET_PATH $TICKET_NUMBER | jq -r ".fields.fixVersions[] | select(.name == \"$VERSION_NAME\") | .name"
}

if [ "$TICKET_NUMBER" == "" ] || [ "$VERSION_NAME" == "" ]; then
  echo "Usage: [ticket number] [version name]"
  echo "  ticket number: the ticket number to update"
  echo "  version name: the version name to add to the ticket"
  exit 1
fi

if [ "$JIRA_GET_TICKET_PATH" == "" ]; then
  JIRA_GET_TICKET_PATH="$SCRIPT_DIR/jira_get_ticket.sh"
fi

if [ "$CURL_PATH" == "" ]; then
  CURL_PATH="$(which curl)"
fi

if [ "$(existing_version)" == "" ]; then
  update_jira_ticket
else
  echo "Ticket $TICKET_NUMBER already has version $VERSION_NAME"
fi
