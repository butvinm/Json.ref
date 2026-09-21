#!/usr/bin/env sh
# Trace a Refal-05 program step by step and print the trace as a valid Refal program on stdout.
#
# Runs the program with the runtime's per-step dump enabled, strips the decorative frame lines and wraps each step in a function named Step-N. Redirect the output to a .ref file to read it with Refal highlighting in an editor.
#
# Usage:
#   scripts/trace.sh [-f] [-s STEP] -- test/test_stringify/run test/test_stringify/in/array.json > .dump.ref
#
#   -f       full dump: view field and buried section on every step (default: only the primary active expression)
#   -s STEP  start dumping from this step (default: 1)

set -eu

full=0
step=1
while [ $# -gt 0 ]; do
  case "$1" in
    -f) full=1; shift ;;
    -s) step="$2"; shift 2 ;;
    --) shift; break ;;
    -*) echo "trace.sh: unknown option $1" >&2; exit 2 ;;
    *) break ;;
  esac
done

if [ $# -eq 0 ]; then
  echo "usage: scripts/trace.sh [-f] [-s STEP] -- PROGRAM [ARGS...]" >&2
  exit 2
fi

if [ "$full" -eq 1 ]; then
  mode=""
else
  mode="-e"
fi

prog="$1"
shift

# The runtime prints the dump on stderr. The program's own stdout is discarded so only the trace remains.
# Each step becomes a function with one sentence per dump section, the section name kept as a comment:
#
#   Step-7 {
#     /* PRIMARY ACTIVE EXPRESSION */ =
#       <DoArgList 1 >;
#
#     /* VIEW FIELD */ =
#       <"Stop$$"
#         <GO0
#           ('test/test_stringify/run' )
#           <DoArgList 1 >>>
#   }
#
# Section content is reindented from the runtime's one space per level to two, under a four space base.
# The runtime indents with one character per level and puts a "." in place of the space in every 4th column as a visual guide. Those dots are part of the indent, not Refal syntax, so they are counted as indent and dropped.
# A section with no content, usually BURIED, is left out.
# When the program crashes, the trace ends with a comment like /* RECOGNITION IMPOSSIBLE on step 41 */. The runtime dumps the failed step once more after that message, that copy is dropped.
# The dump is bytes, not text: the runtime can split a multibyte character or the input can be invalid UTF-8. awk runs in the C locale so it passes such bytes through instead of warning about them.
"$prog" "-d$step" $mode "$@" 2>&1 >/dev/null \
  | LC_ALL=C awk '
      function flush(term) { if (last != "") print last term; last = "" }
      function section(name) { pending = "  /* " name " */ ="; separate = n_sections++ > 0 }
      function close_step() { flush(""); pending = ""; if (open) print "}\n"; open = 0 }

      crashed { next }
      /^(RECOGNITION IMPOSSIBLE|NO MEMORY)$/ {
        close_step()
        print "/* " $0 " on step " num " */"
        crashed = 1
        next
      }
      /^PRIMARY ACTIVE EXPRESSION \(step [0-9]+\):$/ {
        close_step()
        num = $0; sub(/.*step /, "", num); sub(/\).*/, "", num)
        print "Step-" num " {"
        open = 1; n_sections = 0
        section("PRIMARY ACTIVE EXPRESSION")
        next
      }
      /^VIEW FIELD:$/ { section("VIEW FIELD"); next }
      /^BURIED:$/ { section("BURIED"); next }
      /^(\[FIRST\] ?|\[LAST\]|End dump)$/ { next }
      /^$/ { next }
      {
        if (pending != "") {
          if (separate) { flush(";"); print "" } else flush("")
          print pending; pending = ""
        } else flush("")
        depth = 0
        while ((c = substr($0, depth + 1, 1)) == (depth % 4 == 3 ? "." : " ")) depth++
        line = substr($0, depth + 1)
        last = sprintf("%*s%s", 4 + 2 * depth, "", line)
      }
      END { close_step() }
    '
