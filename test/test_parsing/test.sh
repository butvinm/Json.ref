#!/bin/bash

# Runs the parser against the JSONTestSuite parsing tests from ../fixtures/JSONTestSuite/parsing.
# The expected result is defined by the file name prefix:
#   y_ - must be accepted, n_ - must be rejected, i_ - either is fine, but it must not crash.

test_dir=$(dirname "$0")
test_dir=${test_dir#./}
source "$test_dir/../lib.sh"

inputs_dir="$test_dir/../fixtures/JSONTestSuite/parsing"

shopt -s nullglob
inputs=("$inputs_dir"/*.json)

if [[ ${#inputs[@]} -eq 0 ]]; then
    echo "No tests found in $inputs_dir"
    exit 1
fi

begin_session ${#inputs[@]}

for input_file in "${inputs[@]}"; do
    filename=$(basename "$input_file" .json)

    run_limited "$test_dir/run" "$input_file" > "$tmp_dir/$filename.stdout" 2> "$tmp_dir/$filename.stderr"
    exit_code=$?

    case $exit_code in
        0) result=accepted ;;
        2) result=rejected ;;
        *) result=$(crash_message "$exit_code") ;;
    esac

    case $filename in
        y_*) expected=accepted ;;
        n_*) expected=rejected ;;
        *) expected=any ;;
    esac

    if [[ $result != accepted && $result != rejected ]]; then
        record "$input_file" ERROR "$result" "$(grep -v '^[[:space:]]*$' "$tmp_dir/$filename.stderr" | head -n 6 | cut -c "1-$width")"
    elif [[ $expected == any || $expected == "$result" ]]; then
        record "$input_file" PASSED
    else
        record "$input_file" FAILED "$result, must be $expected" "$(cat "$tmp_dir/$filename.stdout")"
    fi
done

end_session
