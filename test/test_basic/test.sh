#!/bin/bash

# Checks the results of Json-Parse, both the parsed values and the parse errors.
# Every .ref file of this directory is a separate program built by make into ./bin.
# A program compares the expected results with the actual ones and crashes on the first mismatch,
# so it passes when it exits with 0.

test_dir=$(dirname "$0")
test_dir=${test_dir#./}
source "$test_dir/../lib.sh"

shopt -s nullglob
sources=("$test_dir"/*.ref)

if [[ ${#sources[@]} -eq 0 ]]; then
    echo "No tests found in $test_dir"
    exit 1
fi

begin_session ${#sources[@]}

for source_file in "${sources[@]}"; do
    name=$(basename "$source_file" .ref)
    program="$test_dir/bin/$name"

    if [[ ! -x "$program" ]]; then
        record "$source_file" ERROR "$program not found, build it with make test-basic"
        continue
    fi

    run_limited "$program" > "$tmp_dir/$name.stdout" 2> "$tmp_dir/$name.stderr"
    exit_code=$?

    case $exit_code in
        0)
            record "$source_file" PASSED
            ;;
        201)
            # recognition impossible: the dump shows the failed Eq call with the expected and the actual results
            record "$source_file" FAILED '' "$(grep -v '^[[:space:]]*$' "$tmp_dir/$name.stderr")"
            ;;
        *)
            record "$source_file" ERROR "$(crash_message "$exit_code")" "$(grep -v '^[[:space:]]*$' "$tmp_dir/$name.stderr" | head -n 6 | cut -c "1-$width")"
            ;;
    esac
done

end_session
