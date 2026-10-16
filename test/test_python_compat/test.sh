#!/bin/bash

# Checks that a file means the same to Python before and after a round trip through Json-Parse and Json-Stringify:
#   json.load(file) == json.load(stringify(parse(file)))
# Inputs are the y_ files of ../test_parsing/in, the ones every parser must accept.
# run.sh performs the full compatibility check for each file.

test_dir=$(dirname "$0")
test_dir=${test_dir#./}
# relative to the current directory when possible, to report short paths without ../
suites_dir=$(cd "$test_dir/.." && pwd)
suites_dir=${suites_dir#"$PWD"/}
inputs_dir="$suites_dir/test_parsing/in"
runner="$test_dir/run.sh"
python=${PYTHON:-python3}
width=80

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
    "$runner" "$input_file" > "$tmp_dir/$filename.details" 2>&1
    exit_code=$?

    case $exit_code in
        0)
            passed=$(( passed + 1 ))
            report "$input_file" PASSED "$green"
            ;;
        1)
            failed+=("$input_file")
            failed_messages+=("$(head -n 1 "$tmp_dir/$filename.details")")
            report "$input_file" FAILED "$red"
            ;;
        *)
            errors+=("$input_file")
            error_messages+=("$(head -n 1 "$tmp_dir/$filename.details")")
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
        [[ -s "$tmp_dir/$filename.details" ]] && cat "$tmp_dir/$filename.details"
        echo
    done
fi

if [[ ${#errors[@]} -gt 0 ]]; then
    bar = ERRORS
    for i in "${!errors[@]}"; do
        filename=$(basename "${errors[$i]}" .json)
        bar _ "${errors[$i]}" "$red$bold"
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
