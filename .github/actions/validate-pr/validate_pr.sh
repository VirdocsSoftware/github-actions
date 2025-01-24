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

function compare_versions() {
  local version1=$1
  local version2=$2

  if [[ $version1 == $version2 ]]; then
    echo "0"
    return
  fi

  local IFS=.
  local i
  local ver1=($version1)
  local ver2=($version2)

  # Fill empty fields in ver1 with zeros
  for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
    ver1[i]=0
  done

  # Fill empty fields in ver2 with zeros
  for ((i=${#ver2[@]}; i<${#ver1[@]}; i++)); do
    ver2[i]=0
  done

  for ((i=0; i<${#ver1[@]}; i++)); do
    if [[ ${ver1[i]} -lt ${ver2[i]} ]]; then
      echo "-1"
      return
    elif [[ ${ver1[i]} -gt ${ver2[i]} ]]; then
      echo "1"
      return
    fi
  done

  echo "0"
}


SEMANTIC_PREFIXES="^(feat|fix|chore|docs|style|refactor|perf|test)[(:]"
JIRA_TICKET="([A-Z]+-[0-9]+)"
VERSION_REGEX="^v([0-9]+)\.([0-9]+)\.([0-9]+)$"

if [[ "$TARGET_BRANCH" == "develop" ]] || [[ "$TARGET_BRANCH" =~ ^release/v ]] || [[ "$TARGET_BRANCH" =~ ^hotfix/v ]]; then
  if [[ "$PR_BRANCH" =~ ^release/v ]] || [[ "$PR_BRANCH" =~ ^hotfix/v ]]; then
    echo "PR title and branch name validation passed."
    exit 0
  fi
  if [[ ! "$PR_TITLE" =~ $SEMANTIC_PREFIXES ]]; then
    echo "PR title must start with a valid semantic prefix (e.g., feat:, fix:)."
    exit 1
  fi

  if [[ ! "$PR_TITLE" =~ $JIRA_TICKET ]]; then
    echo "PR title must contain a valid Jira ticket ID (e.g., ABC-123)."
    exit 1
  fi
fi

if [[ "$TARGET_BRANCH" == "main" ]]; then
  if [[ "$PR_BRANCH" =~ ^release/v ]] || [[ "$PR_BRANCH" =~ ^hotfix/v ]]; then
    if [[ ! "$PR_BRANCH" =~ ^release/v$PACKAGE_VERSION ]] && [[ ! "$PR_BRANCH" =~ ^hotfix/v$PACKAGE_VERSION ]]; then
      echo "Error: Mismatch between the pull request branch and the package version.
Details:
- PR Branch: $PR_BRANCH
- Latest Release: $LATEST_RELEASE
- Package Version: $PACKAGE_VERSION
Action: Update the PR branch name or package version to ensure consistency. 
For more details on naming conventions, refer to our workflow documentation.
See: https://virdocs.atlassian.net/wiki/x/AYAqHAE"
      exit 1
    elif [ "$(compare_versions $PACKAGE_VERSION $LATEST_RELEASE)" != "1" ]; then
      echo "Next predicted version must be higher than the latest release."
      exit 1
    fi
  else
    echo "PR branch must be release/v$PACKAGE_VERSION or hotfix/v$PACKAGE_VERSION"
    exit 1
  fi
  if [[ ! "$PR_BRANCH" =~ ^release/v$PACKAGE_VERSION ]] && [[ ! "$PR_BRANCH" =~ ^hotfix/v$PACKAGE_VERSION ]]; then
    echo "PR branch must be release/v$PACKAGE_VERSION or hotfix/v$PACKAGE_VERSION"
    exit 1
  fi
fi

echo "PR title and branch name validation passed."