# Shared parts of the test.sh runners of the suites: the pytest-like report and running Refal-05 programs with limits.
# A runner sources this file, calls begin_session with the number of items, record for every item and end_session at the end.
# end_session exits with 0 when every item passed and with 1 otherwise.

width=80

# Deeply nested inputs make the parser eat gigabytes in seconds, so both limits matter.
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

# run_limited <program> [argument...]
# -l and -e are options of the Refal-05 runtime: memory limit in megabytes and a short crash dump.
# perl is used for the time limit because stock macOS has no timeout command.
run_limited() {
    local program=$1
    shift
    perl -e 'alarm shift; exec @ARGV' "$time_limit_s" \
        "$program" "-l$memory_limit_mb" -e "$@"
}

# crash_message <exit code of run_limited>
crash_message() {
    case $1 in
        142) echo "timed out after ${time_limit_s}s" ;;
        201) echo "crashed: recognition impossible" ;;
        202) echo "ran out of memory (limit ${memory_limit_mb} MB)" ;;
        *) echo "crashed with exit code $1" ;;
    esac
}

session_total=0
session_names=()
session_statuses=()
session_messages=()
session_details=()

# begin_session <number of items>
begin_session() {
    session_total=$1
    bar = "test session starts" "$bold"
    echo "collected $session_total items"
    echo
}

# record <name> <PASSED | FAILED | ERROR> [message] [details]
# Prints the line of the item at once.
# The message goes to the short test summary, both the message and the details go to the FAILURES or ERRORS section.
record() {
    session_names+=("$1")
    session_statuses+=("$2")
    session_messages+=("${3:-}")
    session_details+=("${4:-}")

    local color=$red
    [[ $2 == PASSED ]] && color=$green
    local percent
    percent=$(printf '[%3d%%]' $(( ${#session_names[@]} * 100 / session_total )))
    local pad=$(( width - ${#1} - ${#2} - ${#percent} - 1 ))
    (( pad < 1 )) && pad=1
    echo "$1 $color$2$reset$(repeat ' ' "$pad")$percent"
}

# section <title> <status>
section() {
    local i printed=0
    for i in "${!session_names[@]}"; do
        [[ ${session_statuses[$i]} == "$2" ]] || continue
        (( printed )) || bar = "$1"
        printed=1
        bar _ "${session_names[$i]}" "$red$bold"
        [[ -n ${session_messages[$i]} ]] && echo "${session_messages[$i]}"
        [[ -n ${session_details[$i]} ]] && printf '%s\n' "${session_details[$i]%$'\n'}"
        echo
    done
}

end_session() {
    echo

    local i passed=0 failed=0 errors=0
    for i in "${!session_names[@]}"; do
        case ${session_statuses[$i]} in
            PASSED) passed=$(( passed + 1 )) ;;
            FAILED) failed=$(( failed + 1 )) ;;
            *) errors=$(( errors + 1 )) ;;
        esac
    done

    section FAILURES FAILED
    section ERRORS ERROR

    if (( failed + errors > 0 )); then
        bar = "short test summary info" "$bold"
        local status
        for status in FAILED ERROR; do
            for i in "${!session_names[@]}"; do
                [[ ${session_statuses[$i]} == "$status" ]] || continue
                echo "$red$status$reset ${session_names[$i]}${session_messages[$i]:+ - ${session_messages[$i]}}"
            done
        done
    fi

    local counts=()
    (( failed > 0 )) && counts+=("$failed failed")
    (( passed > 0 )) && counts+=("$passed passed")
    (( errors == 1 )) && counts+=("1 error")
    (( errors > 1 )) && counts+=("$errors errors")
    local summary
    summary=$(printf '%s, ' "${counts[@]}")
    summary=${summary%, }

    if (( failed + errors > 0 )); then
        bar = "$summary" "$red$bold"
        exit 1
    else
        bar = "$summary" "$green$bold"
        exit 0
    fi
}
