#!/bin/bash

if [ "$CAT_CMD" == "" ]; then
  CAT_CMD="cat"
fi

if [ "$JIRA_API_TOKEN" != "" ] && [ "$JIRA_USERNAME" != "" ] && [ "$JIRA_DOMAIN" != "" ]; then
  JIRA_CONFIG='{"auth": {"user":"'$JIRA_USERNAME'","token":"'$JIRA_API_TOKEN'"},"jira": {"domain": "'$JIRA_DOMAIN'"}}'
  echo $JIRA_CONFIG
  exit 0
fi
if [ "$JIRA_CONFIG" == "" ]; then
  if [ "$JIRA_CONFIG_FILE" == "" ]; then
    JIRA_CONFIG_FILE="$HOME/.jira-cli/config.json"
  fi
  $CAT_CMD $JIRA_CONFIG_FILE
else
  echo $JIRA_CONFIG
fi
