"""
Compare two JSON files as Python values and exit with 0 if they are equal.
run.sh runs this for an input file and its copy that went through Json-Parse and Json-Stringify.

Exit codes: 1 - the values differ, 2 - Python can't load the round-tripped file, 3 - Python can't load the original file.
"""

import json
import sys
from decimal import Decimal
from pathlib import Path


def load(path: str, exit_code: int):
    # bytes, not text: the round-tripped file may be not a valid UTF-8, and that must be reported, not crash the script
    try:
        return json.loads(Path(path).read_bytes(), parse_float=Decimal)
    except (ValueError, RecursionError) as error:
        print(f'{path}: {type(error).__name__}: {error}')
        sys.exit(exit_code)


def equal_values(left, right) -> bool:
    # JSON has one number type, but booleans must not compare equal to 0 or 1.
    if type(left) in (int, Decimal) and type(right) in (int, Decimal):
        return left == right
    if type(left) is not type(right):
        return False
    if isinstance(left, list):
        return len(left) == len(right) and all(
            equal_values(a, b) for a, b in zip(left, right)
        )
    if isinstance(left, dict):
        return left.keys() == right.keys() and all(
            equal_values(left[key], right[key]) for key in left
        )
    return left == right


def main() -> None:
    if len(sys.argv) != 3:
        print(f'usage: {sys.argv[0]} <original.json> <round-tripped.json>')
        sys.exit(64)

    original_path, round_tripped_path = sys.argv[1:]
    original = load(original_path, 3)
    round_tripped = load(round_tripped_path, 2)

    if not equal_values(original, round_tripped):
        # values are aligned to be compared at a glance
        width = max(len(original_path), len(round_tripped_path)) + 1
        print(f'{original_path + ":":<{width}} {original!r}')
        print(f'{round_tripped_path + ":":<{width}} {round_tripped!r}')
        sys.exit(1)


if __name__ == '__main__':
    main()
