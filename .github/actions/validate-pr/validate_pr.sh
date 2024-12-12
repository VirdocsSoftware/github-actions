#!/bin/sh -l

if [ "$PR_TITLE" == "" ]; then
  echo "env variable PR_TITLE is required"
  exit 1
fi
if [ "$PR_BRANCH" == "" ]; then
  echo "env variable PR_BRANCH is required"
  exit 1
fi
if [ "$LATEST_RELEASE" == "" ]; then
  echo "env variable LATEST_RELEASE is required"
  exit 1
fi
if [ "$TARGET_BRANCH" == "" ]; then
  echo "env variable TARGET_BRANCH is required"
  exit 1
fi

SEMANTIC_PREFIXES="^(feat|fix|chore|docs|style|refactor|perf|test):"
JIRA_TICKET="([A-Z]+-[0-9]+)"
VERSION_REGEX="^v([0-9]+)\.([0-9]+)\.([0-9]+)$"

if [[ ! "$PR_TITLE" =~ $SEMANTIC_PREFIXES ]]; then
  echo "PR title must start with a valid semantic prefix (e.g., feat:, fix:)."
  exit 1
fi

if [[ ! "$PR_TITLE" =~ $JIRA_TICKET ]]; then
  echo "PR title must include a Jira ticket number (e.g., ISSUE-1234)."
  exit 1
fi

# Add more validation logic as needed