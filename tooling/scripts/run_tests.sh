#!/bin/bash

FILES=$(dirname $0)/tests/*_test.sh

function run_tests() {
  local files=$1
  for f in $files
  do
    echo "Processing $f file..."
    local parent_folder=$(dirname $(dirname $f))
    local file_name=$(basename $f)
    local script_file=$(echo $file_name | sed 's/_test[.]sh$/.sh/')
    $f "$parent_folder/$script_file"
    if [ "$?" != "0" ]; then
      exit 1
    fi
done
}

run_tests "$FILES"
