
#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

function expect() {
  if [ "$1" != "$2" ]; then
    echo "Expected: $2"
    echo "Actual:   $1"
    exit 1
  else
    echo "OK"
  fi
}

beforeAll() {
  export TESTING=true
}

beforeEach() {
  export PR_TITLE="feat: This is a PR title (ISSUE-1234)"
  export PR_BRANCH="feature/ISSUE-1234"
  export LATEST_RELEASE="1.0.0"
  export PACKAGE_VERSION="1.1.0"
  export TARGET_BRANCH="develop"
}

beforeAll

echo Scenario: PR title missing semantic prefix for feature branch
beforeEach

# GIVEN
export PR_TITLE="This is a PR title (ISSUE-1234)"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "1"
expect "$ACTUAL" "PR title must start with a valid semantic prefix (e.g., feat:, fix:)."

echo Scenario: PR title missing Jira ticket for feature branch
beforeEach

# GIVEN
export PR_TITLE="feat: This is a PR title"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "1"
expect "$ACTUAL" "PR title must include a Jira ticket number (e.g., ISSUE-1234)."

echo Scenario: Valid PR title for feature branch
beforeEach

# GIVEN
export PR_TITLE="feat: This is a PR title (ISSUE-1234)"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"

echo Scenario: Non release or hotfix branch targeting the main branch
beforeEach

# GIVEN
export PR_BRANCH="TICKET-123"
export TARGET_BRANCH="main"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "1"
expect "$ACTUAL" "PR branch must be release/v1.1.0 or hotfix/v1.1.0"

echo Scenario: Package version and branch name mismatch
beforeEach

# GIVEN
export PR_BRANCH="release/v1.1.0"
export TARGET_BRANCH="main"
export PACKAGE_VERSION="1.0.0"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "1"
expect "$ACTUAL" "PR branch and package version must match"

echo Scenario: Valid feature branch to develop branch
beforeEach

# GIVEN
export PR_BRANCH="feature/ISSUE-1234"
export TARGET_BRANCH="develop"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"

echo Scenario: Valid release branch to main branch
beforeEach

# GIVEN
export PR_BRANCH="release/v1.1.0"
export TARGET_BRANCH="main"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"

echo Scenario: Valid hotfix branch to main branch
beforeEach

# GIVEN
export PR_BRANCH="hotfix/v1.1.0"
export TARGET_BRANCH="main"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"
