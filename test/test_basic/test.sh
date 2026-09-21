#!/bin/bash

# Checks the results of Json-Parse, both the parsed values and the parse errors.
# Every .ref file of this directory is a separate program built by make into ./bin.
# A program compares the expected results with the actual ones and crashes on the first mismatch,
# so it passes when it exits with 0.

test_dir=$(dirname "$0")
test_dir=${test_dir#./}
width=80

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
run_test() {
    perl -e 'alarm shift; exec @ARGV' "$time_limit_s" \
        "$1" "-l$memory_limit_mb" -e
}

shopt -s nullglob
sources=("$test_dir"/*.ref)
total=${#sources[@]}

if [[ $total -eq 0 ]]; then
    echo "No tests found in $test_dir"
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
for source_file in "${sources[@]}"; do
    index=$(( index + 1 ))
    name=$(basename "$source_file" .ref)
    program="$test_dir/bin/$name"

    if [[ ! -x "$program" ]]; then
        errors+=("$source_file")
        error_messages+=("$program not found, build it with make test-basic")
        report "$source_file" ERROR "$red"
        continue
    fi

    run_test "$program" > "$tmp_dir/$name.stdout" 2> "$tmp_dir/$name.stderr"
    exit_code=$?

    case $exit_code in
        0)
            passed=$(( passed + 1 ))
            report "$source_file" PASSED "$green"
            ;;
        201)
            # recognition impossible: the dump shows the failed Eq call with the expected and the actual results
            failed+=("$source_file")
            report "$source_file" FAILED "$red"
            ;;
        142)
            errors+=("$source_file")
            error_messages+=("timed out after ${time_limit_s}s")
            report "$source_file" ERROR "$red"
            ;;
        202)
            errors+=("$source_file")
            error_messages+=("ran out of memory (limit ${memory_limit_mb} MB)")
            report "$source_file" ERROR "$red"
            ;;
        *)
            errors+=("$source_file")
            error_messages+=("crashed with exit code $exit_code")
            report "$source_file" ERROR "$red"
            ;;
    esac
done
echo

if [[ ${#failed[@]} -gt 0 ]]; then
    bar = FAILURES
    for source_file in "${failed[@]}"; do
        name=$(basename "$source_file" .ref)
        bar _ "$source_file" "$red$bold"
        grep -v '^[[:space:]]*$' "$tmp_dir/$name.stderr"
        echo
    done
fi

if [[ ${#errors[@]} -gt 0 ]]; then
    bar = ERRORS
    for i in "${!errors[@]}"; do
        name=$(basename "${errors[$i]}" .ref)
        bar _ "${errors[$i]}" "$red$bold"
        echo "${error_messages[$i]}"
        [[ -s "$tmp_dir/$name.stderr" ]] && grep -v '^[[:space:]]*$' "$tmp_dir/$name.stderr" | head -n 6 | cut -c "1-$width"
        echo
    done
fi

if [[ ${#failed[@]} -gt 0 || ${#errors[@]} -gt 0 ]]; then
    bar = "short test summary info" "$bold"
    for source_file in "${failed[@]}"; do
        echo "${red}FAILED$reset $source_file"
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
