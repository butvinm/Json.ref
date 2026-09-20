#!/bin/bash

# Checks that a file means the same to Python before and after a round trip through Json-Parse and Json-Stringify:
#   json.load(file) == json.load(stringify(parse(file)))
# Inputs are the y_ files of ../test_parsing/in, the ones every parser must accept.
# The round trip is done by the test_basic runner, which prints the parsed file stringified back.

test_dir=$(dirname "$0")
test_dir=${test_dir#./}
# relative to the current directory when possible, to report short paths without ../
suites_dir=$(cd "$test_dir/.." && pwd)
suites_dir=${suites_dir#"$PWD"/}
inputs_dir="$suites_dir/test_parsing/in"
runner="$suites_dir/test_basic/run"
python=${PYTHON:-python3}
width=80

memory_limit_mb=${MEMORY_LIMIT_MB:-256}
time_limit_s=${TIME_LIMIT_S:-10}

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

# The round-tripped files are kept after the run to look at what exactly Json-Stringify printed.
out_dir="$test_dir/out"
rm -rf "$out_dir"
mkdir -p "$out_dir"

if [[ -t 1 ]]; then
    red=$'\033[31m' green=$'\033[32m' bold=$'\033[1m' reset=$'\033[0m'
else
    red='' green='' bold='' reset=''
fi

repeat() {
    printf '%*s' "$2" '' | tr ' ' "$1"
}

# bar <fill char> <text> [color]
bar() {
    local text=" $2 "
    local left=$(( (width - ${#text}) / 2 ))
    local right=$(( width - ${#text} - left ))
    (( left < 1 )) && left=1
    (( right < 1 )) && right=1
    echo "${3:-}$(repeat "$1" "$left")$text$(repeat "$1" "$right")$reset"
}

# report <path> <status> <color>
report() {
    local percent
    percent=$(printf '[%3d%%]' $(( index * 100 / total )))
    local pad=$(( width - ${#1} - ${#2} - ${#percent} - 1 ))
    (( pad < 1 )) && pad=1
    echo "$1 $3$2$reset$(repeat ' ' "$pad")$percent"
}

# -l and -e are options of the Refal-05 runtime: memory limit in megabytes and a short crash dump.
# perl is used for the time limit because stock macOS has no timeout command.
run_round_trip() {
    perl -e 'alarm shift; exec @ARGV' "$time_limit_s" \
        "$runner" "-l$memory_limit_mb" -e "$1"
}

if ! command -v "$python" > /dev/null; then
    echo "$python not found, set PYTHON to the interpreter to compare with"
    exit 1
fi

shopt -s nullglob
inputs=("$inputs_dir"/y_*.json)
total=${#inputs[@]}

if [[ $total -eq 0 ]]; then
    echo "No tests found in $inputs_dir"
    exit 1
fi

bar = "test session starts" "$bold"
echo "collected $total items"
echo

passed=0
failed=()
failed_messages=()
errors=()
error_messages=()
index=0
for input_file in "${inputs[@]}"; do
    index=$(( index + 1 ))
    filename=$(basename "$input_file" .json)
    actual_file="$out_dir/$filename.json"

    run_round_trip "$input_file" > "$actual_file" 2> "$tmp_dir/$filename.stderr"
    exit_code=$?

    case $exit_code in
        0) result=accepted ;;
        2) result=rejected ;;
        142) result="timed out after ${time_limit_s}s" ;;
        202) result="ran out of memory (limit ${memory_limit_mb} MB)" ;;
        *) result="crashed with exit code $exit_code" ;;
    esac

    if [[ $result == rejected ]]; then
        failed+=("$input_file")
        failed_messages+=("rejected by Json-Parse")
        echo "$actual_file: $(cat "$actual_file")" > "$tmp_dir/$filename.details"
        report "$input_file" FAILED "$red"
        continue
    elif [[ $result != accepted ]]; then
        errors+=("$input_file")
        error_messages+=("$result")
        {
            echo "$actual_file: incomplete, the runner $result"
            grep -v '^[[:space:]]*$' "$tmp_dir/$filename.stderr" | head -n 6 | cut -c "1-$width"
        } > "$tmp_dir/$filename.details"
        report "$input_file" ERROR "$red"
        continue
    fi

    "$python" "$test_dir/compare.py" "$input_file" "$actual_file" > "$tmp_dir/$filename.details" 2>&1
    exit_code=$?

    case $exit_code in
        0)
            passed=$(( passed + 1 ))
            report "$input_file" PASSED "$green"
            ;;
        1)
            failed+=("$input_file")
            failed_messages+=("round-tripped value differs")
            report "$input_file" FAILED "$red"
            ;;
        2)
            failed+=("$input_file")
            failed_messages+=("$python can't load the round-tripped file")
            report "$input_file" FAILED "$red"
            ;;
        3)
            errors+=("$input_file")
            error_messages+=("$python can't load the original file")
            report "$input_file" ERROR "$red"
            ;;
        *)
            errors+=("$input_file")
            error_messages+=("compare.py exited with code $exit_code")
            report "$input_file" ERROR "$red"
            ;;
    esac
done
echo

if [[ ${#failed[@]} -gt 0 ]]; then
    bar = FAILURES
    for i in "${!failed[@]}"; do
        filename=$(basename "${failed[$i]}" .json)
        bar _ "${failed[$i]}" "$red$bold"
        echo "${failed_messages[$i]}"
        [[ -s "$tmp_dir/$filename.details" ]] && cat "$tmp_dir/$filename.details"
        echo
    done
fi

if [[ ${#errors[@]} -gt 0 ]]; then
    bar = ERRORS
    for i in "${!errors[@]}"; do
        filename=$(basename "${errors[$i]}" .json)
        bar _ "${errors[$i]}" "$red$bold"
        echo "${error_messages[$i]}"
        [[ -s "$tmp_dir/$filename.details" ]] && cat "$tmp_dir/$filename.details"
        echo
    done
fi

if [[ ${#failed[@]} -gt 0 || ${#errors[@]} -gt 0 ]]; then
    bar = "short test summary info" "$bold"
    for i in "${!failed[@]}"; do
        echo "${red}FAILED$reset ${failed[$i]} - ${failed_messages[$i]}"
    done
    for i in "${!errors[@]}"; do
        echo "${red}ERROR$reset ${errors[$i]} - ${error_messages[$i]}"
    done
fi

counts=()
[[ ${#failed[@]} -gt 0 ]] && counts+=("${#failed[@]} failed")
[[ $passed -gt 0 ]] && counts+=("$passed passed")
[[ ${#errors[@]} -eq 1 ]] && counts+=("1 error")
[[ ${#errors[@]} -gt 1 ]] && counts+=("${#errors[@]} errors")
summary=$(printf '%s, ' "${counts[@]}")
summary=${summary%, }

if [[ ${#failed[@]} -gt 0 || ${#errors[@]} -gt 0 ]]; then
    bar = "$summary" "$red$bold"
    exit 1
else
    bar = "$summary" "$green$bold"
    exit 0
fi
