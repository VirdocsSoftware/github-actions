
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
expect "$ACTUAL" "PR title must contain a valid Jira ticket ID (e.g., ABC-123)."

echo Scenario: PR title missing Jira ticket for feature branch targeting hotfix branch
beforeEach

# GIVEN
export PR_TITLE="feat: This is a PR title"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "1"
expect "$ACTUAL" "PR title must contain a valid Jira ticket ID (e.g., ABC-123)."

echo Scenario: Valid PR title for feature branch
beforeEach

# GIVEN
export PR_TITLE="feat: This is a PR title (ISSUE-1234)"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"
expect "PR title and branch name validation passed." "$ACTUAL"

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

echo Scenario: Next Release version is not higher than the latest version
beforeEach

# GIVEN
export PR_BRANCH="release/v1.0.0"
export TARGET_BRANCH="main"
export PACKAGE_VERSION="1.0.0"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "1"
expect "$ACTUAL" "Next predicted version must be higher than the latest release."

echo Scenario: Valid feature branch to develop branch
beforeEach

# GIVEN
export PR_BRANCH="feature/ISSUE-1234"
export TARGET_BRANCH="develop"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"

echo Scenario: Valid feature branch to release branch
beforeEach

# GIVEN
export PR_BRANCH="feature/ISSUE-1234"
export TARGET_BRANCH="release/v1.1.0"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"

echo Scenario: Valid feature branch to hotfix branch
beforeEach

# GIVEN
export PR_BRANCH="feature/ISSUE-1234"
export TARGET_BRANCH="hotfix/v1.1.0"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"

echo Scenario: Valid release branch to main branch
beforeEach

# GIVEN
export PR_BRANCH="release/v1.1.0"
export TARGET_BRANCH="main"
export PR_TITLE="release v1.1.0 to main"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"

echo Scenario: Valid hotfix branch to main branch
beforeEach

# GIVEN
export PR_BRANCH="hotfix/v1.1.0"
export TARGET_BRANCH="main"
export PR_TITLE="hotfix v1.1.0 to main"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"

echo Scenario: Valid release branch merging to develop
beforeEach

# GIVEN
export PR_BRANCH="release/v1.1.0"
export TARGET_BRANCH="develop"
export PR_TITLE="release v1.1.0 to develop"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"

echo Scenario: Valid pr title for fix branch merging to develop
beforeEach

# GIVEN
export PR_BRANCH="fix-PAR-2061-remove-unnecessary-message-types"
export TARGET_BRANCH="develop"
export PR_TITLE="fix(PAR-2061): Remove unnecessary message types"

# WHEN
ACTUAL="$($SCRIPT_DIR/validate_pr.sh)"

# THEN
expect "$?" "0"