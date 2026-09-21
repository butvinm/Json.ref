"""
Compare two JSON files as Python values and exit with 0 if they are equal.
test.sh runs this for each input file and its copy that went through Json-Parse and Json-Stringify.

Exit codes: 1 - the values differ, 2 - Python can't load the round-tripped file, 3 - Python can't load the original file.
"""

import json
import sys
from pathlib import Path


def load(path: str, exit_code: int):
    # bytes, not text: the round-tripped file may be not a valid UTF-8, and that must be reported, not crash the script
    try:
        return json.loads(Path(path).read_bytes())
    except (ValueError, RecursionError) as error:
        print(f'{path}: {type(error).__name__}: {error}')
        sys.exit(exit_code)


def main() -> None:
    if len(sys.argv) != 3:
        print(f'usage: {sys.argv[0]} <original.json> <round-tripped.json>')
        sys.exit(64)

    original_path, round_tripped_path = sys.argv[1:]
    original = load(original_path, 3)
    round_tripped = load(round_tripped_path, 2)

    if original != round_tripped:
        # values are aligned to be compared at a glance
        width = max(len(original_path), len(round_tripped_path)) + 1
        print(f'{original_path + ":":<{width}} {original!r}')
        print(f'{round_tripped_path + ":":<{width}} {round_tripped!r}')
        sys.exit(1)


if __name__ == '__main__':
    main()
