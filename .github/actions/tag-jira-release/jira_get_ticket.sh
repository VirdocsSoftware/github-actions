#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

TOKEN=$JIRA_TOKEN
USERNAME=$JIRA_EMAIL
if [ "$JIRA_DOMAIN" == "" ] || [ "$JIRA_DOMAIN" == "null" ]; then
  echo "Please set the jira domain in the config file"
  exit
fi

if [ "$1" == "" ]; then
  echo "Usage: [ticket id] (option)"
  echo " options:"
  echo "    --history -h: show usage history"
  echo "    --links   -l: show web links"
  exit 1
fi

if [ "$2" == "--history" ] || [ "$2" == "-h" ]; then
  EXPAND="?expand=changelog"
elif [ "$2" == "--links" ] || [ "$2" == "-l" ]; then
  EXPAND="/remotelink"
else
  EXPAND=
fi

TICKET_ID=$1

TICKET_INFO=$(curl \
  -X GET \
  --user ${USERNAME}:${TOKEN} \
  -H "Content-Type: application/json" \
  "https://$JIRA_DOMAIN/rest/api/2/issue/$TICKET_ID$EXPAND" 2>/dev/null)

echo $TICKET_INFO | jq .
