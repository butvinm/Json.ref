#!/bin/bash

# Runs the parser against the JSONTestSuite parsing tests from ./in.
# The expected result is defined by the file name prefix:
#   y_ - must be accepted, n_ - must be rejected, i_ - either is fine, but it must not crash.

test_dir=$(dirname "$0")
test_dir=${test_dir#./}
width=80

# Deeply nested files make the parser eat gigabytes in seconds, so both limits matter.
memory_limit_mb=${MEMORY_LIMIT_MB:-256}
time_limit_s=${TIME_LIMIT_S:-10}

tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

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
run_parser() {
    perl -e 'alarm shift; exec @ARGV' "$time_limit_s" \
        "$test_dir/run" "-l$memory_limit_mb" -e "$1"
}

shopt -s nullglob
inputs=("$test_dir"/in/*.json)
total=${#inputs[@]}

if [[ $total -eq 0 ]]; then
    echo "No tests found in $test_dir/in"
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

    run_parser "$input_file" > "$tmp_dir/$filename.stdout" 2> "$tmp_dir/$filename.stderr"
    exit_code=$?

    case $exit_code in
        0) result=accepted ;;
        2) result=rejected ;;
        142) result="timed out after ${time_limit_s}s" ;;
        202) result="ran out of memory (limit ${memory_limit_mb} MB)" ;;
        *) result="crashed with exit code $exit_code" ;;
    esac

    case $filename in
        y_*) expected=accepted ;;
        n_*) expected=rejected ;;
        *) expected=any ;;
    esac

    if [[ $result != accepted && $result != rejected ]]; then
        errors+=("$input_file")
        error_messages+=("$result")
        report "$input_file" ERROR "$red"
    elif [[ $expected == any || $expected == "$result" ]]; then
        passed=$(( passed + 1 ))
        report "$input_file" PASSED "$green"
    else
        failed+=("$input_file")
        failed_messages+=("$result, must be $expected")
        report "$input_file" FAILED "$red"
    fi
done
echo

if [[ ${#failed[@]} -gt 0 ]]; then
    bar = FAILURES
    for i in "${!failed[@]}"; do
        filename=$(basename "${failed[$i]}" .json)
        bar _ "$filename" "$red$bold"
        echo "${failed_messages[$i]}"
        [[ -s "$tmp_dir/$filename.stdout" ]] && cat "$tmp_dir/$filename.stdout"
        echo
    done
fi

if [[ ${#errors[@]} -gt 0 ]]; then
    bar = ERRORS
    for i in "${!errors[@]}"; do
        filename=$(basename "${errors[$i]}" .json)
        bar _ "$filename" "$red$bold"
        echo "${error_messages[$i]}"
        grep -v '^[[:space:]]*$' "$tmp_dir/$filename.stderr" | head -n 6 | cut -c "1-$width"
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
