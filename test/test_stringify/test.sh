#!/bin/bash

# Checks what Json-Stringify prints for a parsed file:
#   stringify(parse(./in/name.json)) == ./expected/name.json
# The actual results are kept in ./out after the run, it is not tracked by git.

test_dir=$(dirname "$0")
test_dir=${test_dir#./}
source "$test_dir/../lib.sh"

out_dir="$test_dir/out"
rm -rf "$out_dir"
mkdir -p "$out_dir"

shopt -s nullglob
inputs=("$test_dir"/in/*.json)

if [[ ${#inputs[@]} -eq 0 ]]; then
    echo "No tests found in $test_dir/in"
    exit 1
fi

begin_session ${#inputs[@]}

for input_file in "${inputs[@]}"; do
    filename=$(basename "$input_file" .json)
    expected_file="$test_dir/expected/$filename.json"
    actual_file="$out_dir/$filename.json"

    if [[ ! -f "$expected_file" ]]; then
        record "$input_file" ERROR "expected file $expected_file not found"
        continue
    fi

    run_limited "$test_dir/run" "$input_file" > "$actual_file" 2> "$tmp_dir/$filename.stderr"
    exit_code=$?

    # 0 is a parsed file, 2 is a reported parse error, which is printed and shows up in the diff
    if [[ $exit_code -ne 0 && $exit_code -ne 2 ]]; then
        record "$input_file" ERROR "$(crash_message "$exit_code")" "$(cat "$tmp_dir/$filename.stderr")"
    elif diff -u -L "$expected_file" -L "$actual_file" "$expected_file" "$actual_file" > "$tmp_dir/$filename.diff"; then
        record "$input_file" PASSED
    else
        record "$input_file" FAILED '' "$(cat "$tmp_dir/$filename.diff")"
    fi
done

end_session
