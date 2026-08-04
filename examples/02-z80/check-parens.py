#!/usr/bin/env python3
"""Check paren balance in fab .lisp files (ignoring strings and comments)."""
import re, sys

def check_file(path):
    text = open(path).read()
    # Strip string contents and comments
    cleaned = re.sub(r'"[^"]*"', '""', text)
    cleaned = re.sub(r';.*$', '', cleaned, flags=re.MULTILINE)
    depth = 0
    for i, line in enumerate(cleaned.split('\n'), start=1):
        for ch in line:
            if ch == '(':
                depth += 1
            elif ch == ')':
                depth -= 1
        if depth < 0:
            print(f"FAIL {path}: negative depth {depth} at line {i}")
            return False
    if depth != 0:
        print(f"FAIL {path}: final depth {depth} (need 0)")
        return False
    print(f"OK   {path}")
    return True

if __name__ == '__main__':
    ok = all(check_file(f) for f in sys.argv[1:])
    sys.exit(0 if ok else 1)
