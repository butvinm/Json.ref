#!/bin/bash

set -e

export R05CCOMP="clang -o test/run"
refal05c test/run Json Library LibraryEx refal05rts

failed=0
for input_file in ./test/in/*.json; do
    filename=$(basename "$input_file" .json)

    output_file="./test/out/$filename.json"

    if [[ ! -f "$output_file" ]]; then
        echo "Output file $output_file does not exist, skipping..."
        failed=1
        continue
    fi

    echo "Running test for $input_file..."
    ./test/run "$input_file" > ./test/run_output.json

    if diff -q ./test/run_output.json "$output_file" > /dev/null; then
        echo "Test passed for $filename."
    else
        echo "Test failed for $filename. Differences:"
        diff ./test/run_output.json "$output_file" || true
        failed=1
    fi

    rm ./test/run_output.json
done

if [[ $failed -eq 1 ]]; then
    echo "One or more tests failed."
    exit 1
else
    echo "All tests passed."
    exit 0
fi
