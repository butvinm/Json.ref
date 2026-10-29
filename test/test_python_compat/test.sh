#!/bin/bash

# Checks that a file means the same to Python before and after a round trip through Json-Parse and Json-Stringify:
#   json.load(file) == json.load(stringify(parse(file)))
# Inputs are the y_ files of ../fixtures/JSONTestSuite/parsing, the ones every parser must accept.
# run.sh performs the full compatibility check for each file.

test_dir=$(dirname "$0")
test_dir=${test_dir#./}
source "$test_dir/../lib.sh"

# relative to the current directory when possible, to report short paths without ../
suites_dir=$(cd "$test_dir/.." && pwd)
suites_dir=${suites_dir#"$PWD"/}
inputs_dir="$suites_dir/fixtures/JSONTestSuite/parsing"
runner="$test_dir/run.sh"
python=${PYTHON:-python3}

# The round-tripped files are kept after the run to look at what exactly Json-Stringify printed.
out_dir="$test_dir/out"
rm -rf "$out_dir"
mkdir -p "$out_dir"

if ! command -v "$python" > /dev/null; then
    echo "$python not found, set PYTHON to the interpreter to compare with"
    exit 1
fi

shopt -s nullglob
inputs=("$inputs_dir"/y_*.json)

if [[ ${#inputs[@]} -eq 0 ]]; then
    echo "No tests found in $inputs_dir"
    exit 1
fi

begin_session ${#inputs[@]}

for input_file in "${inputs[@]}"; do
    filename=$(basename "$input_file" .json)
    details_file="$tmp_dir/$filename.details"
    "$runner" "$input_file" > "$details_file" 2>&1
    exit_code=$?

    # run.sh prints the reason on its first line
    case $exit_code in
        0) record "$input_file" PASSED ;;
        1) record "$input_file" FAILED "$(head -n 1 "$details_file")" "$(tail -n +2 "$details_file")" ;;
        *) record "$input_file" ERROR "$(head -n 1 "$details_file")" "$(tail -n +2 "$details_file")" ;;
    esac
done

end_session
