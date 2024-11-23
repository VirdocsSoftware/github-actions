#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
JIRA_CONFIG="$($SCRIPT_DIR/jira_get_config.sh)"

TOKEN=$(echo $JIRA_CONFIG | jq -r .auth.token)
USERNAME=$(echo $JIRA_CONFIG | jq -r .auth.user)
JIRA_DOMAIN=$(echo $JIRA_CONFIG | jq -r .jira.domain)
if [ "$JIRA_DOMAIN" == "" ] || [ "$JIRA_DOMAIN" == "null" ]; then
  echo "Please set the jira domain in the config file"
  exit
fi

if [ "$1" == "" ]; then
  echo "Usage: [JQL]"
  exit 1
fi

JQL=$1

function urlencode() {
  # urlencode <string>
  old_lc_collate=$LC_COLLATE
  LC_COLLATE=C
  local length="${#1}"
  for (( i = 0; i < length; i++ )); do
    local c="${1:i:1}"
    case $c in
      [a-zA-Z0-9.~_-]) printf "$c" ;;
      *) printf '%%%02X' "'$c" ;;
    esac
  done
  LC_COLLATE=$old_lc_collate
}

JQL=$(urlencode "$JQL")

TICKET_INFO=$(curl \
  -X GET \
  --user ${USERNAME}:${TOKEN} \
  -H "Content-Type: application/json" \
  "https://$JIRA_DOMAIN.atlassian.net/rest/api/2/search?jql=$JQL" 2>/dev/null)

echo $TICKET_INFO | jq .
