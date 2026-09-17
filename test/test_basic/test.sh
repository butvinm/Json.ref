#!/bin/bash

test_dir=$(dirname "$0")
test_dir=${test_dir#./}
width=80

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
errors=()
error_messages=()
index=0
for input_file in "${inputs[@]}"; do
    index=$(( index + 1 ))
    filename=$(basename "$input_file" .json)
    output_file="$test_dir/out/$filename.json"
    actual_file="$tmp_dir/$filename.json"

    if [[ ! -f "$output_file" ]]; then
        errors+=("$input_file")
        error_messages+=("expected file $output_file not found")
        report "$input_file" ERROR "$red"
        continue
    fi

    "$test_dir/run" "$input_file" > "$actual_file" 2> "$tmp_dir/$filename.stderr"
    exit_code=$?

    # 0 is a parsed file, 2 is a reported parse error, both print something to compare
    if [[ $exit_code -ne 0 && $exit_code -ne 2 ]]; then
        errors+=("$input_file")
        error_messages+=("runner exited with code $exit_code")
        report "$input_file" ERROR "$red"
    elif diff -u -L "expected $output_file" -L actual "$output_file" "$actual_file" > "$tmp_dir/$filename.diff"; then
        passed=$(( passed + 1 ))
        report "$input_file" PASSED "$green"
    else
        failed+=("$input_file")
        report "$input_file" FAILED "$red"
    fi
done
echo

if [[ ${#failed[@]} -gt 0 ]]; then
    bar = FAILURES
    for input_file in "${failed[@]}"; do
        filename=$(basename "$input_file" .json)
        bar _ "$filename" "$red$bold"
        cat "$tmp_dir/$filename.diff"
        echo
    done
fi

if [[ ${#errors[@]} -gt 0 ]]; then
    bar = ERRORS
    for i in "${!errors[@]}"; do
        filename=$(basename "${errors[$i]}" .json)
        bar _ "$filename" "$red$bold"
        echo "${error_messages[$i]}"
        [[ -s "$tmp_dir/$filename.stderr" ]] && cat "$tmp_dir/$filename.stderr"
        echo
    done
fi

if [[ ${#failed[@]} -gt 0 || ${#errors[@]} -gt 0 ]]; then
    bar = "short test summary info" "$bold"
    for input_file in "${failed[@]}"; do
        echo "${red}FAILED$reset $input_file"
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
