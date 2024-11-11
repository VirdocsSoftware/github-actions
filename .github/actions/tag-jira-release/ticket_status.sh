#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

TOKEN=$JIRA_TOKEN
USERNAME=$JIRA_EMAIL
if [ "$JIRA_DOMAIN" == "" ] || [ "$JIRA_DOMAIN" == "null" ]; then
  echo "Please set the JIRA_DOMAIN environment variable"
  exit
fi
CURRENT_BRANCH=$1
if [ "$CURRENT_BRANCH" == "" ]; then
  echo "Usage: [current_branch] [(optional) target_branch]"
  exit 1
fi
TARGET_BRANCH=main
if [ "$2" != "" ]; then
  TARGET_BRANCH=$2
fi

HASHES=$(git log $TARGET_BRANCH..$CURRENT_BRANCH --pretty=format:'%H')

if [ ! -d ~/temp ]; then
  mkdir ~/temp
fi

while IFS= read -r hash; do
  LOG=$(git show $hash | sed '/^diff/,$d')
  TICKET_IDS=$(echo $LOG | grep -o '[A-Z][A-Z]*-[0-9][0-9]*' | sort | uniq)
  if [ "$TICKET_IDS" != "" ]; then
    echo $TICKET_IDS > ~/temp/$hash.txt
  fi
done <<< "$HASHES"

function getTicketInfo() {
  ticketId=$1
  if [[ "$ticketId" =~ ^ISSUE-[0-9]+$ ]]; then
    echo -n "\"url\":\"https://github.com/robaone/source/issues/$(echo $ticketId | sed 's/ISSUE-//')\""
  else
    TICKET_INFO=$(curl \
      -X GET \
      --user ${USERNAME}:${TOKEN} \
      -H "Content-Type: application/json" \
      "https://${JIRA_DOMAIN}/rest/api/2/issue/$ticketId" 2>/dev/null)
     echo -n "\"url\":\"https://${JIRA_DOMAIN}/browse/$ticketId\",\"status\":\"$(echo $TICKET_INFO | jq -r .fields.status.name)\""
  fi
}

while IFS= read -r hash; do
  FILE=~/temp/$hash.txt
  if [ -f "$FILE" ]; then
    while IFS= read -r ticketId; do
      if [ "$ticketId" != "" ]; then
        echo -n "{\"hash\":\"$hash\","
        getTicketInfo $ticketId
        echo "}"
      fi
    done <<< "$(cat $FILE | sed 's/ /\n/g')"
  fi
done <<< "$HASHES"
exit 0
# Cleanup
while IFS= read -r hash; do
  FILE=~/temp/$hash.txt
  if [ -f "$FILE" ] && [ "$FILE" != "" ]; then
    rm ~/temp/$hash.txt
  fi
done <<< "$HASHES"
