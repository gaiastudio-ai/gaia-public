#!/usr/bin/env python3
"""Normalize a sprint-state-machine JSONL trace for parity diff.

Reads newline-delimited JSON records from the argv[1] file (or stdin when
argv[1] is "-"), drops the `timestamp` field, and prints the remaining
records one per line, sorted by key order, to stdout. Used by the
cluster-19 sprint-state-machine bats harness to diff native captures
against the v-parity-baseline oracle (E28-S135 AC4).

Usage:
    normalize-trace.py <path.jsonl>
    cat path.jsonl | normalize-trace.py -
"""
import json
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    src = sys.stdin if sys.argv[1] == "-" else open(sys.argv[1])
    try:
        for line in src:
            line = line.strip()
            if not line:
                continue
            record = json.loads(line)
            record.pop("timestamp", None)
            print(json.dumps(record, sort_keys=True))
    finally:
        if src is not sys.stdin:
            src.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
