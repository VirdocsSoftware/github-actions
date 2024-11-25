#!/bin/bash

# configuration

if [ "$EVENT" != "pull_request" ]; then
  echo "Not applicable"
  exit 0
fi
if [ "$PACKAGE_PATH" == "" ]; then
  PACKAGE_PATH=.
fi
if [ "$SCRIPT_PATH" == "" ]; then
  SCRIPT_PATH=$(dirname $BASH_SOURCE)
fi
if [ "$JQ_PATH" == "" ]; then
  JQ_PATH=$(which jq)
  if [ -z "$JQ_PATH" ]; then
    echo "jq is not installed"
    exit 1
  fi
fi
if [ "$GIT_PATH" == "" ]; then
  GIT_PATH=$(which git)
  if [ -z "$GIT_PATH" ]; then
    echo "git is not installed"
    exit 1
  fi
fi
if [ "$FIGLET_PATH" == "" ]; then
  FIGLET_PATH=$(which figlet)
  if [ -z "$FIGLET_PATH" ]; then
    echo "figlet is not installed"
    exit 1
  fi
fi

# get branch info 

CURRENT_BRANCH=$($GIT_PATH rev-parse --abbrev-ref HEAD);
PARSED_BRANCH_VERSION=$(echo $CURRENT_BRANCH | sed -E 's/(release|hotfix)\/v//')
if [ "$TARGET_BRANCH" == "" ]; then
  echo "Target branch is not specified in TARGET_BRANCH environment variable"
  exit 1
fi
if [ "$TARGET_BRANCH" != "main" ]; then
  echo "Nothing to do here"
  exit 0
fi
PACKAGE_VERSION=$($JQ_PATH -r .version $PACKAGE_PATH/package.json);
if [ "$NEXT_PREDICTED_RELEASE" == "" ]; then
  NEXT_PREDICTED_RELEASE=$($SCRIPT_PATH/git_predict_next_version.sh)
fi
if [ "$NEXT_PREDICTED_RELEASE" != "$PACKAGE_VERSION" ]; then
  echo "Release Version = $NEXT_PREDICTED_RELEASE";
  echo "Package Version = $PACKAGE_VERSION";
  echo "
See: https://github.com/company/Answers/discussions/158"
  exit 1
else
  echo "Everything is good.  Ready to release"
  $FIGLET_PATH "version $PACKAGE_VERSION"
fi
