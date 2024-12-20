#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

ORIGINAL_TARGET_BRANCH=$TARGET_BRANCH

if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
  echo "Usage: [option]"
  echo "  options:"
  echo "    --dry-run: print the next version and the tickets that will be tagged"
  exit 0
fi

if [ "$1" == "--dry-run" ]; then
  DRY_RUN=true
fi

if [ "$TICKET_STATUS_PATH" == "" ]; then
  TICKET_STATUS_PATH="$SCRIPT_DIR/ticket_status.sh"
fi

if [ "$GIT_PREDICT_NEXT_VERSION_PATH" == "" ]; then
  GIT_PREDICT_NEXT_VERSION_PATH=$SCRIPT_DIR/git_predict_next_version.sh
fi

if [ "$CREATE_RELEASE_PATH" == "" ]; then
  CREATE_RELEASE_PATH=$SCRIPT_DIR/jira_create_release.sh
fi

if [ "$JIRA_GET_TICKET_PATH" == "" ]; then
  JIRA_GET_TICKET_PATH="$SCRIPT_DIR/jira_get_ticket.sh"
fi

if [ "$DRY_RUN" == "true" ]; then
  SET_TICKET_FIX_VERSION_PATH=echo
  CREATE_RELEASE_PATH=echo
else
  if [ "$SET_TICKET_FIX_VERSION_PATH" == "" ]; then
    SET_TICKET_FIX_VERSION_PATH=$SCRIPT_DIR/jira_set_ticket_fix_version.sh
  fi
fi

if [ "$GIT_CMD_PATH" == "" ]; then
  GIT_CMD_PATH=$(which git)
fi

if [ "$DESCRIPTION" == "" ]; then
  DESCRIPTION="Next awesome release"
fi

function get_repository_name() {
  if [ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1; then
    local repository_name=$(git remote -v | grep origin | head -1 | awk -F/ '{print $NF}' | sed 's/.git//' | awk '{print $1}')
    echo $repository_name
  else
    echo "Not a Git repository." >&2
    exit 1
  fi
} 

if [ "$REPOSITORY" == "" ]; then
  REPOSITORY="$(get_repository_name)"
  if [ "$REPOSITORY" == "" ]; then
    exit 1
  fi
fi
# to lower case
REPOSITORY=$(echo "$REPOSITORY" | tr '[:upper:]' '[:lower:]')

function get_current_branch() {
  local current_branch=$($GIT_CMD_PATH rev-parse --abbrev-ref HEAD)
  echo $current_branch
}

function get_target_branch() {
  # if release branch exists, use that
  # else use the main branch
  local next_version="$1"
  local release_branch="origin/release/v$next_version"
  if [ "$($GIT_CMD_PATH branch -r | grep $release_branch)" != "" ]; then
    echo $release_branch
  else
    echo $TARGET_BRANCH
  fi
}

function increment_version() {
  local version="$1"
  local major=$(echo "$version" | cut -d. -f1)
  local minor=$(echo "$version" | cut -d. -f2)
  local patch=$(echo "$version" | cut -d. -f3)
  echo "$major.$((minor+1)).0"
}

function get_next_release_number() {
  local target_branch="$1"
  local next_version="$2"
  if [ "$target_branch" == "$ORIGINAL_TARGET_BRANCH" ]; then
    echo "$next_version"
  else
    increment_version "$next_version"
  fi
}

function get_tickets_in_current_branch() {
  local target_branch="$1"
  echo "Checking for tickets between $(get_current_branch) and $target_branch" >&2
  local ticket_info="$($TICKET_STATUS_PATH $(get_current_branch) $target_branch)"
  echo "$ticket_info" >&2
  echo "$ticket_info" | grep -v '"Done"' | grep -v "Cancelled" | jq -r .url | sort | uniq | sed 's/https:\/\/'$JIRA_DOMAIN'\/browse\///g'
}

function existing_version() {
  $JIRA_GET_TICKET_PATH $1 | jq -r ".fields.fixVersions[] | select(.name == \"$2\") | .name"
}

NEXT_PREDICTED_VERSION="$($GIT_PREDICT_NEXT_VERSION_PATH)"
if [ "$IS_RELEASE" == "true" ]; then
  echo "Using target branch $TARGET_BRANCH"
else
  TARGET_BRANCH="$(get_target_branch $NEXT_PREDICTED_VERSION)"
fi
TICKETS="$(get_tickets_in_current_branch $TARGET_BRANCH)"

if [ "$TICKETS" == "" ]; then
  echo "No tickets found"
  exit 0
fi

echo Tickets found: $TICKETS

NEXT_VERSION=$(get_next_release_number "$TARGET_BRANCH" "$NEXT_PREDICTED_VERSION")


if [ "$?" != "0" ]; then
  echo "Failed to create release $REPOSITORY-v$NEXT_VERSION"
  exit 1
else
  if [ "$DRY_RUN" == "true" ]; then
    echo "********************************"
    echo "Next version: $REPOSITORY-v$NEXT_VERSION"
    echo "********************************"
  fi
fi
for TICKET in $TICKETS; do
  export JIRA_PROJECT=$(echo $TICKET | sed 's/-.*//')
  if [ "$NOTIFICATION_SCRIPT" != "" ]; then
    # get the existing version
    existing_version=$(existing_version $TICKET $REPOSITORY-v$NEXT_VERSION)
    if [ "$existing_version" == "" ]; then
      $NOTIFICATION_SCRIPT "Tag https://$JIRA_DOMAIN/browse/$TICKET with $REPOSITORY-v$NEXT_VERSION"
    fi
  fi
  $CREATE_RELEASE_PATH "$REPOSITORY-v$NEXT_VERSION" "$DESCRIPTION" 2>/dev/null
  if [ "$?" != "0" ]; then
    exit $?
  fi
  if [ "$SKIP_ASSIGN_TAG" == "true" ]; then
    continue
  fi
  echo "Tag $TICKET with $REPOSITORY-v$NEXT_VERSION" && \
    $SET_TICKET_FIX_VERSION_PATH "$TICKET" "$REPOSITORY-v$NEXT_VERSION" 2>/dev/null
  if [ "$?" != "0" ]; then
    exit $?
  fi
done
