#!/bin/bash

YEAR="$1" # Release year
RELEASE_NAME="$2"
RELEASE_END_DATE="$3"
RELEASE_NOTES_FILE="$4"

if [ "$PARENT_PAGE_ID" == "" ]; then
    PARENT_PAGE_ID="4489150471"
fi

if [ "$UPDATE_EXISTING" == "" ]; then
    export UPDATE_EXISTING="false" # Do not update the folder page if it exists by default
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
JIRA_CONFIG="$($SCRIPT_DIR/jira_get_config.sh)"
ATLASSIAN_USER=$(echo $JIRA_CONFIG | jq -r .auth.user)
ATLASSIAN_API_TOKEN=$(echo $JIRA_CONFIG | jq -r .auth.token)
DOMAIN="$(echo $JIRA_CONFIG | jq -r .jira.domain)"

if [ "$GET_PAGE_CMD" == "" ]; then
    GET_PAGE_CMD="$SCRIPT_DIR/confluence_get_pages.sh"
fi

if [ "$CREATE_PAGE_CMD" == "" ]; then
    CREATE_PAGE_CMD="$SCRIPT_DIR/confluence_post_page.sh"
fi

PAGE_TITLE="$RELEASE_END_DATE Release Notes - $RELEASE_NAME"

show_usage() {
    echo "Usage: [year] [release_name] [release_end_date] [release_notes_file]"
    exit 1
}

get_parent_page() {
    local response="$($GET_PAGE_CMD -i "$PARENT_PAGE_ID")"
    echo $response
}

create_release_notes() {
    local parent_page_id=$1
    local space_id="$2"
    local title="$3"
    local body="$4"
    export UPDATE_EXISTING="true" # Update existing page if it exists
    local response="$($CREATE_PAGE_CMD "$parent_page_id" "$space_id" "$title" "$body")"
    local response_id="$(echo $response | jq -r .id)"
    if [ "$response_id" == "" ] || [ "$response_id" == "null" ]; then
        echo "Error creating release notes"
        exit 1
    fi
    echo $response
}

main() {
    local parent_page="$(get_parent_page)"
    local space_id="$(echo $parent_page | jq -r '.spaceId')"
    create_release_notes "$PARENT_PAGE_ID" "$space_id" "$PAGE_TITLE" "$(cat $RELEASE_NOTES_FILE)"
}

# check if any arguments are blank
if [ -z "$YEAR" ] || [ -z "$RELEASE_NAME" ] || [ -z "$RELEASE_END_DATE" ] || [ -z "$RELEASE_NOTES_FILE" ]; then
    show_usage
fi
if [ ! -f "$RELEASE_NOTES_FILE" ]; then
    echo "Release notes file not found"
    exit 1
fi
main
exit $?
