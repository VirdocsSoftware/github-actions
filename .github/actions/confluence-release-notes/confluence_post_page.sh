#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

JIRA_CONFIG="$($SCRIPT_DIR/jira_get_config.sh)"
ATLASSIAN_USER=$(echo $JIRA_CONFIG | jq -r .auth.user)
ATLASSIAN_API_TOKEN=$(echo $JIRA_CONFIG | jq -r .auth.token)
DOMAIN="$(echo $JIRA_CONFIG | jq -r .jira.domain)"

if [ "$CURL_CMD" == "" ]; then
    CURL_CMD="curl"
fi

if [ "$GET_PAGE_CMD" == "" ]; then
    GET_PAGE_CMD="$SCRIPT_DIR/confluence_get_pages.sh"
fi

function find_page() {
    local SPACE_ID=$1
    local PAGE_TITLE="$2"
    local response="$($GET_PAGE_CMD -t "$PAGE_TITLE")"
    local length=$(echo $response | jq -r '.results | length' )
    if [ "$length" == "0" ]; then
        echo ""
    else
        echo $response | jq '.results[] | select(.spaceId == "'"$SPACE_ID"'")' | jq --slurp '{id: .[0].id, version: .[0].version.number, spaceId: .[0].spaceId}'
    fi
}

function create_page() {
    local PARENT_PAGE_ID=$1
    local SPACE_ID=$2
    local PAGE_TITLE="$3"
    local PAGE_CONTENT="$4"
    local payload="{\"status\": \"current\"}"
    # build the payload using jq
    # {
    #         "status": "current",
    #         "title": "'"$PAGE_TITLE"'",
    #         "parentId": "'"$PARENT_PAGE_ID"'",
    #         "spaceId": "'"$SPACE_ID"'",
    #         "body": {
    #             "storage": {
    #                 "value": "'"$PAGE_CONTENT"'",
    #                 "representation": "storage"
    #             }
    #         }
    #     }
    payload=$(echo $payload | jq --arg title "$PAGE_TITLE" '. + {title: $title}')
    payload=$(echo $payload | jq --arg parent_id "$PARENT_PAGE_ID" '. + {parentId: $parent_id}')
    payload=$(echo $payload | jq --arg space_id "$SPACE_ID" '. + {spaceId: $space_id}')
    payload=$(echo $payload | jq --arg page_content "$PAGE_CONTENT" '. + {body: {storage: {value: $page_content, representation: "storage"}}}')

    local response="$($CURL_CMD --silent --request POST \
        --url "https://$DOMAIN.atlassian.net/wiki/api/v2/pages" \
        --user "$ATLASSIAN_USER:$ATLASSIAN_API_TOKEN" \
        --header 'Accept: application/json' \
        --header 'Content-Type: application/json' \
        --data "$payload")"
    echo $response
}

function update_page() {
    local PAGE_ID=$1
    local SPACE_ID=$2
    local PAGE_TITLE="$3"
    local PAGE_CONTENT="$4"
    local OLD_VERSION=$5
    local VERSION=$((OLD_VERSION + 1))
    local payload="{\"status\":\"current\"}"
    # build the payload using jq
    # {
    #     "id": "'"$PAGE_ID"'",
    #     "status": "current",
    #     "title": "'"$PAGE_TITLE"'",
    #     "body": {
    #         "value": "'"$PAGE_CONTENT"'",
    #         "representation": "storage"
    #     },
    #     "version": {
    #         "number": "'$VERSION'",
    #         "message": "Updated page content"
    #     }
    # }
    payload=$(echo $payload | jq --arg id "$PAGE_ID" '. + {id: $id}')
    payload=$(echo $payload | jq --arg title "$PAGE_TITLE" '. + {title: $title}')
    payload=$(echo $payload | jq --arg page_content "$PAGE_CONTENT" '. + {body: {storage: {value: $page_content, representation: "storage"}}}')
    payload=$(echo $payload | jq --arg version "$VERSION" '. + {version: {number: $version, message: "Updated page content"}}')
    local response="$($CURL_CMD --silent --request PUT \
        --url "https://$DOMAIN.atlassian.net/wiki/api/v2/pages/$PAGE_ID" \
        --user "$ATLASSIAN_USER:$ATLASSIAN_API_TOKEN" \
        --header 'Accept: application/json' \
        --header 'Content-Type: application/json' \
        --data "$payload")"
    echo $response
}

function main() {
    local PARENT_PAGE_ID=$1
    local SPACE_ID=$2
    local PAGE_TITLE="$3"
    local PAGE_CONTENT="$4"

    local existing_page="$(find_page "$SPACE_ID" "$PAGE_TITLE")"
    if [ "$existing_page" == "" ]; then
        create_page $PARENT_PAGE_ID $SPACE_ID "$PAGE_TITLE" "$PAGE_CONTENT"
    elif [ "$UPDATE_EXISTING" != "false" ]; then
        local old_version=$(echo $existing_page | jq -r .version)
        local existing_page_id=$(echo $existing_page | jq -r .id)
        update_page $existing_page_id $SPACE_ID "$PAGE_TITLE" "$PAGE_CONTENT" "$old_version"
    else
        echo $existing_page
    fi
}

if [ "$1" == "" ] || [ "$2" == "" ] || [ "$3" == "" ] || [ "$4" == "" ]; then
    echo "Usage: <parent_page_id> <space_id> <page_title> <page_content>"
    exit 1
fi
main "$@"
exit $?