#!/bin/bash

if [ "$VERSIONS" == "" ]; then
  VERSIONS="$(git tag -l "v*")"
fi

function convert_to_number() {

  # Split
  IFS='.'
  read -ra newarr <<< "$1"

  if [ "${#newarr[@]}" != 3 ]; then
    echo "Invalid version number" 1>&2
    exit 1
  fi

  echo "${newarr[0]}$((${newarr[1]}+100000))$((${newarr[2]}+100000))"
}

function compare_versions {
  a=$1
  b=$2

  if [ "$a" == "" ] || [ "$b" == "" ]; then
    echo "Usage: [version1] [version2]" 1>&2
    exit 1
  fi

  if (( 10#$(convert_to_number "$a") > 10#$(convert_to_number "$b") )); then
    echo "1"
  elif (( 10#$(convert_to_number "$a") < 10#$(convert_to_number "$b") )); then
    echo "-1"
  else
    echo "0"
  fi

}

function cleanup_version() {
  echo "$1" | grep -o "^v[0-9][0-9]*[.][0-9][0-9]*[.][0-9][0-9]*$" | sed 's/^.//'
}
# Loop overs line in variable
while IFS= read -r VERSION; do
  if [ "$VERSION" != "" ]; then
    # Cleanup version
    VERSION=$(cleanup_version $VERSION)
    # Get the latest version
    if [ "$LATEST_VERSION" == "" ]; then
      LATEST_VERSION=$VERSION
    fi
    # Compare the version
    if [ "$VERSION" != "" ]; then
      if [ "$LATEST_VERSION" != "" ]; then
        if [ "$(compare_versions $VERSION $LATEST_VERSION)" == "1" ]; then
          LATEST_VERSION=$VERSION
        fi
      fi
    fi
  fi
done <<< "$VERSIONS"

echo $LATEST_VERSION
