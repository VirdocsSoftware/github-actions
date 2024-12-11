#!/bin/bash

BASE_FOLDER="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
if [ "$CURRENT_VERSION" == "" ] && [ "$TESTING" != "true" ]; then
  CURRENT_VERSION=$($BASE_FOLDER/git_latest_version_tag.sh)
fi

if [ "$1" == "-v" ] || [ "$1" == "--verbose" ]; then
  VERBOSE=true
fi

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  echo "Usage: [(optional) option]"
  echo " -h --help   : Print the help instructions"
  echo " -v --verbose: Print out the changelog"
  exit 0
fi 

if [ "$CURRENT_VERSION" == "" ]; then
  echo "1.0.0"
  exit 0
fi

IFS='.' read -a version_parts <<< "$CURRENT_VERSION"

major=${version_parts[0]}
minor=${version_parts[1]}
patch=${version_parts[2]}
git fetch

function get_logs() {
  if [ "$GIT_LOGS" == "" ]; then
    git log $(git merge-base HEAD origin/main)..HEAD
  else
    echo "$GIT_LOGS"
  fi
}

GIT_LOGS="$(get_logs)"

BREAKING_CHANGES="$(echo "$GIT_LOGS" | grep "^\s*BREAKING CHANGE:")"
MINOR_CHANGES="$(echo "$GIT_LOGS" | grep "^\s*feat[(:]")"
PATCH_CHANGES="$(echo "$GIT_LOGS" | grep "^\s*fix[(:]")"

function print_changes() {
  local title=$1
  local changes="$2"
  if [ "$changes" != "" ]; then
    echo "$title"
    echo "=============="
    echo ""
    echo "$changes"
    echo ""
  fi
}

if [ "$VERBOSE" == "true" ]; then
  print_changes "Breaking Changes:" "$BREAKING_CHANGES"
  print_changes "Minor Changes:" "$MINOR_CHANGES"
  print_changes "Patch Changes:" "$PATCH_CHANGES"
fi

if [ "$(get_logs | grep "^\s*BREAKING CHANGE:")" != "" ]; then
  major=$((major+1))
  minor=0
  patch=0
elif [ "$(get_logs | grep "^\s*feat[(:]")" != "" ]; then
  minor=$((minor+1))
  patch=0
elif [ "$(get_logs | grep "^\s*fix[(:]")" != "" ]; then
  patch=$((patch+1))
fi

echo "$major.$minor.$patch"
