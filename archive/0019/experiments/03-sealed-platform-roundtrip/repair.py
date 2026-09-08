#!/usr/bin/env python3
"""Repair two `cue def` printer defects that make its output unparseable.

Neither is a CUE-language problem; both are how the printer renders source it
just read. They are reported here as measurements, not worked around silently.

1. A trailing `// explicit error (_|_ literal) in source` comment is appended to
   a line ending in `_|_`. When that line is one arm of a multi-line boolean,
   the comment swallows the rest of the expression.
2. A multi-line boolean is broken BEFORE its operator, so a continuation line
   starts with `||` or `&&`. CUE terminates the expression at the newline, and
   the continuation is a syntax error.
"""
import sys, pathlib

src = pathlib.Path(sys.argv[1])
text = src.read_text()

comment = " // explicit error (_|_ literal) in source"
n_comments = text.count(comment)
text = text.replace(comment, "")

out, n_joined = [], 0
for line in text.split("\n"):
    stripped = line.lstrip()
    if out and (stripped.startswith("||") or stripped.startswith("&&")):
        out[-1] = out[-1].rstrip() + " " + stripped.rstrip()
        n_joined += 1
    else:
        out.append(line)

src.write_text("\n".join(out))
print(f"{n_comments} trailing _|_ comments removed, {n_joined} operator-leading lines joined")
