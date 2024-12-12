#!/bin/bash

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
if [ "$PACKAGE_VERSION" == "" ]; then
  echo "env variable PACKAGE_VERSION is required"
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

if [[ "$TARGET_BRANCH" == "main" ]]; then
  if [[ "$PR_BRANCH" =~ ^release/v ]] || [[ "$PR_BRANCH" =~ ^hotfix/v ]]; then
    if [[ ! "$PR_BRANCH" =~ ^release/v$PACKAGE_VERSION ]] && [[ ! "$PR_BRANCH" =~ ^hotfix/v$PACKAGE_VERSION ]]; then
      echo "PR branch and package version must match"
      exit 1
    else
      exit 0
    fi
  else
    echo "PR branch must be release/v$PACKAGE_VERSION or hotfix/v$PACKAGE_VERSION"
    exit 1
  fi
  if [[ ! "$PR_BRANCH" =~ ^feature/v$PACKAGE_VERSION ]] && [[ ! "$PR_BRANCH" =~ ^hotfix/v$PACKAGE_VERSION ]]; then
    echo "PR branch must be release/v$PACKAGE_VERSION or hotfix/v$PACKAGE_VERSION"
    exit 1
  fi
fi