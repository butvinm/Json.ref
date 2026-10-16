#!/bin/bash

# Check one file through Json-Parse, Json-Stringify, and Python's json.
# Exit codes: 0 - passed, 1 - failed, 2 - error.

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <file.json>"
    exit 2
fi

test_dir=$(dirname "$0")
test_dir=${test_dir#./}
input_file=$1
python=${PYTHON:-python3}
memory_limit_mb=${MEMORY_LIMIT_MB:-256}
time_limit_s=${TIME_LIMIT_S:-10}

if [[ ! -f "$input_file" ]]; then
    echo "input file not found: $input_file"
    exit 2
fi
if [[ ! -x "$test_dir/run" ]]; then
    echo "runner not found, build it with make test/test_python_compat/run"
    exit 2
fi
if ! command -v "$python" > /dev/null; then
    echo "$python not found, set PYTHON to the interpreter to compare with"
    exit 2
fi

tmp_dir=$(mktemp -d) || exit 2
trap 'rm -rf "$tmp_dir"' EXIT
out_dir="$test_dir/out"
mkdir -p "$out_dir" || exit 2
filename=$(basename "$input_file" .json)
actual_file="$out_dir/$filename.json"

# perl supplies the time limit on macOS, which has no stock timeout command.
perl -e 'alarm shift; exec @ARGV' "$time_limit_s" \
    "$test_dir/run" "-l$memory_limit_mb" -e "$input_file" \
    > "$actual_file" 2> "$tmp_dir/stderr"
exit_code=$?

case $exit_code in
    0) ;;
    2)
        echo "rejected by Json-Parse"
        echo "$actual_file: $(cat "$actual_file")"
        exit 1
        ;;
    *)
        case $exit_code in
            142) result="timed out after ${time_limit_s}s" ;;
            202) result="ran out of memory (limit ${memory_limit_mb} MB)" ;;
            *) result="crashed with exit code $exit_code" ;;
        esac
        echo "$result"
        echo "$actual_file: incomplete, the runner $result"
        grep -v '^[[:space:]]*$' "$tmp_dir/stderr" | head -n 6 | cut -c 1-80
        exit 2
        ;;
esac

"$python" "$test_dir/compare.py" "$input_file" "$actual_file" > "$tmp_dir/details" 2>&1
exit_code=$?
case $exit_code in
    0) echo "PASSED: $input_file"; exit 0 ;;
    1) echo "round-tripped value differs" ;;
    2) echo "$python can't load the round-tripped file" ;;
    3) echo "$python can't load the original file" ;;
    *) echo "compare.py exited with code $exit_code" ;;
esac
cat "$tmp_dir/details"
case $exit_code in
    1|2) exit 1 ;;
    *) exit 2 ;;
esac
