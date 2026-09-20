#!/usr/bin/env python3
import json
import sys

def format_json(input_str: str) -> str:
    return json.dumps(
        json.loads(input_str),
        indent=4,
        ensure_ascii=False,
        sort_keys=False
    )

if __name__ == "__main__":
    filepath = sys.argv[1]
    with open(filepath, "r", encoding="utf-8") as f:
        raw = f.read()
    pretty = format_json(raw)
    with open(filepath, "w", encoding="utf-8") as fout:
        fout.write(pretty)
