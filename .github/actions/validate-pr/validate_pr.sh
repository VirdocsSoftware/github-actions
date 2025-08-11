#!/bin/bash

if [ "$PR_TITLE" == "" ]; then
  echo "Error: Missing required environment variable PR_TITLE
Action: Please set the PR_TITLE environment variable."
  exit 1
fi
if [ "$PR_BRANCH" == "" ]; then
  echo "Error: Missing required environment variable PR_BRANCH
Action: Please set the PR_BRANCH environment variable."
  exit 1
fi
if [ "$LATEST_RELEASE" == "" ]; then
  echo "Error: Missing required environment variable LATEST_RELEASE
Action: Please set the LATEST_RELEASE environment variable."
  exit 1
fi
if [ "$PACKAGE_VERSION" == "" ]; then
  echo "Error: Missing required environment variable PACKAGE_VERSION
Action: Please set the PACKAGE_VERSION environment variable."
  exit 1
fi
if [ "$TARGET_BRANCH" == "" ]; then
  echo "Error: Missing required environment variable TARGET_BRANCH
Action: Please set the TARGET_BRANCH environment variable."
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


SEMANTIC_PREFIXES="^(feat|fix|chore|ci|docs|style|refactor|perf|test)[(:]"
JIRA_TICKET="([A-Z]+-[0-9]+)"
VERSION_REGEX="v([0-9]+)\.([0-9]+)\.([0-9]+)"

if [ "$PR_BRANCH" == "main" ] && [ "$TARGET_BRANCH" == "develop" ]; then
  echo "Everything is good"
  exit 0
fi

if [[ "$TARGET_BRANCH" == "develop" ]] || [[ "$TARGET_BRANCH" =~ ^release/v ]] || [[ "$TARGET_BRANCH" =~ ^hotfix/v ]]; then
  if [[ "$PR_BRANCH" =~ ^release/v ]] || [[ "$PR_BRANCH" =~ ^hotfix/v ]]; then
    echo "PR title and branch name validation passed."
    exit 0
  fi
  if [[ ! "$PR_TITLE" =~ $SEMANTIC_PREFIXES ]]; then
    echo "Error: Invalid PR title format
Details:
- Current title: $PR_TITLE
Action: Update the PR title to start with a valid semantic prefix
Valid prefixes: feat:, fix:, chore:, ci:, docs:, style:, refactor:, perf:, test:
Example: feat: Add new feature (ABC-123)
Note: You must push a new commit to update this validation result"
    exit 1
  fi

  if [[ ! "$PR_TITLE" =~ $JIRA_TICKET ]]; then
    echo "Error: Missing Jira ticket reference in PR title
Details:
- Current title: $PR_TITLE
Action: Include a Jira ticket ID in the PR title using the format (ABC-123)
Example: feat: Add new feature (ABC-123)"
    exit 1
  fi
fi

if [[ "$TARGET_BRANCH" == "main" ]]; then
  if [[ "$PR_BRANCH" =~ ^release/v ]] || [[ "$PR_BRANCH" =~ ^hotfix/v ]]; then
    BASE_BRANCH_VERSION=$(echo "$PR_BRANCH" | grep -oE "v[0-9]+\.[0-9]+\.[0-9]+")
    if [[ ! "$BASE_BRANCH_VERSION" =~ ^v$PACKAGE_VERSION ]] && [[ ! "$BASE_BRANCH_VERSION" =~ ^v$PACKAGE_VERSION ]]; then
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
      echo "Error: Invalid version increment
Details:
- Current version: $PACKAGE_VERSION
- Latest release: $LATEST_RELEASE
Action: Update the package version to be higher than the latest release
Example: If latest is 1.0.0, next version should be > 1.0.0 (e.g., 1.0.1, 1.1.0, 2.0.0)
For version numbering guidelines, see: https://semver.org/"
      exit 1
    fi
  else
    echo "Error: Invalid branch name for main target
Details:
- Current branch: $PR_BRANCH
- Target branch: main
Action: Only release or hotfix branches can be merged to main
Expected format: release/v$PACKAGE_VERSION or hotfix/v$PACKAGE_VERSION"
    exit 1
  fi
  if [[ ! "$BASE_BRANCH_VERSION" =~ ^v$PACKAGE_VERSION ]] && [[ ! "$BASE_BRANCH_BRANCH" =~ ^v$PACKAGE_VERSION ]]; then
    echo "Error: Branch name does not match package version
Details:
- Current branch: $PR_BRANCH
- Package version: $PACKAGE_VERSION
Action: Rename branch to match package version
Expected format: release/v$PACKAGE_VERSION or hotfix/v$PACKAGE_VERSION"
    exit 1
  fi
fi

echo "PR title and branch name validation passed."
