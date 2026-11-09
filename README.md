# goose-diff

[![ci](https://github.com/rekanalar/goose-diff/actions/workflows/ci.yml/badge.svg)](https://github.com/rekanalar/goose-diff/actions/workflows/ci.yml)

Text differences for Goose. The package computes a diff of two texts. It writes the diff in the unified format. It reads a unified patch. It applies a patch to a text.

## Install

```goose
import diff from "rekanalar/goose-diff@v0.1.0";
```

The package uses the standard library only. It has no other dependency.

## Reference libraries

| Library | What the package matches |
|---|---|
| Python `difflib` | `SequenceMatcher.get_opcodes`, the grouping of hunks, the format of a range, the format of a unified diff |
| Node `diff` (jsdiff) | `createPatch`, `applyPatch`, the reading of a patch, the reverse apply |
| Rust `similar` | The unified output, the reading of a patch, the apply of a patch |
| Go `go-difflib` | `GetUnifiedDiffString`, the writing of a unified diff |

## Features

- **A minimal diff of two texts.** The search is the Myers diff. The result holds the opcodes of the change, as `difflib` gives them.
- **The unified format.** The output follows GNU `diff -u`. It holds the file names, the hunk headers and the lines of the change.
- **The patch of several files.** One patch holds many files, each with many hunks. The reader skips the lines before a file header, such as `Index:` and `diff --git`.
- **The apply of a patch.** The apply checks every context line and every removed line. It finds a hunk that sits at another line than its header says.
- **The reverse apply.** The patch takes the text back to the form before the change.
- **A bounded search.** The search for a hunk spends from a budget. A patch that needs too much work is a fault, not a hang.
- **The minimality flag.** Every diff call gives a flag. The flag is true when the diff holds the most equal lines that any diff can hold.

## API

| Call | What it does |
|---|---|
| `diff_lines(a, b, o, ops)` | Adds the opcodes of `a` against `b` to `ops`. Gives a code and the minimality flag |
| `unified_diff(out, a, b, a_name, b_name, o)` | Adds the unified diff of `a` against `b` to `out`. Gives a code and the minimality flag |
| `patch_parse(text, files, hunks, body)` | Reads a unified patch. Gives a code |
| `patch_apply(src, text, files, hunks, body, file, o, out)` | Adds the text of `src` after one file of a patch is applied. Gives a code |
| `default_options()` | The rules of most calls: 3 lines of context, 2000 edits, 16 MiB of input |
| `default_apply_options()` | The rules of most applies: a forward apply, 50 million compares, a shift of 1 million lines, 16 MiB of input |
| `error_text(code)` | Names a code |

### The opcodes

| Field | Meaning |
|---|---|
| `tag` | `OP_EQUAL`, `OP_DELETE`, `OP_INSERT` or `OP_REPLACE` |
| `a_lo`, `a_hi` | The range of the lines of the first text. The end is the first line outside the range |
| `b_lo`, `b_hi` | The range of the lines of the second text |

### The rules of a diff

| Field | Meaning | Default |
|---|---|---|
| `context` | The lines of context around a change in the unified output | 3 |
| `max_edits` | The most edits that the search takes. It goes from 1 to 3000 | 2000 |
| `max_input` | The most bytes of one input | 16777216 |

### The rules of an apply

| Field | Meaning | Default |
|---|---|---|
| `reverse` | Apply the patch the other way | false |
| `max_work` | The most line compares that the search spends | 50000000 |
| `max_shift` | The most lines that a hunk may move from the place of its header | 1000000 |
| `max_input` | The most bytes of the text | 16777216 |

### The codes

| Code | The fault |
|---|---|
| `ERR_OK` | No fault |
| `ERR_TOO_LARGE` | An input, a file count or a hunk count is over the limit |
| `ERR_BAD_OPTION` | A rule is out of range |
| `ERR_BAD_NAME` | A file name holds a line end |
| `ERR_BAD_PATCH` | The patch is not a valid unified patch |
| `ERR_NO_MATCH` | A hunk matches no place in the text |
| `ERR_TOO_MUCH_WORK` | The search for a hunk took too much work |
| `ERR_NO_FILE` | The patch holds no such file |

A call that fails leaves the buffer of the caller as it was.

## Example

```goose
import std;
import diff from "rekanalar/goose-diff@v0.1.0";

fn main() {
    var out: u8[>..] = [];
    let code, exact = diff::unified_diff(out, "one\ntwo\n", "one\nthree\n", "a.txt", "b.txt",
                                         diff::default_options());
    assert(code == diff::ERR_OK && exact);
    print(out[..]);
}
```

## Security

- **The search for a hunk spends from a budget.** The apply counts the line compares. It stops at `max_work` and gives `ERR_TOO_MUCH_WORK`. A patch that moves a hunk far gives `ERR_NO_MATCH`. A hostile patch cannot make the search run forever.
- **The counts of a patch are checked against its body**. A hunk header may not count more lines than the body holds. A patch may not ask for a big count and give few lines.
- **A line that the counts do not ask for is a fault**. It comes after the last line of a hunk. GNU `patch` refuses it too. The package refuses it, so a patch cannot carry a change that the apply drops without a fault.
- **The numbers of a header are bounded.** A number of more than 15 digits is a fault. A header cannot ask for a line number beyond the range of the machine.
- **The file count and the hunk count are bounded.** A patch holds at most 10000 files and 100000 hunks.
- **The size of an input is bounded.** A text of more than 16 MiB is a fault.
- **The diff of two texts is minimal.** The search keeps a trace of the order of its square. The rule `max_edits` bounds that trace. The cap of 3000 keeps the trace of one call at about 36 MB. Past the bound, the diff stays valid, but it is not minimal. The call says so with its flag.
- **The rules of a diff stay in range**. The rule `context` goes to 1073741824. The rule `max_edits` goes to 3000. A rule beyond its cap is a fault. So no rule can wrap the arithmetic of the output or of the search.
- **The lines of a text never join into one byte.** Every line keeps its line end. A line of the text can hold any byte, so a diff never splits a line of a text.
- **A failed call changes nothing**. A fault in the read of a patch rolls back the file list, the hunk list and the body list. A fault in an apply rolls back the output buffer.

Risks that stay: the package reads a patch and a text from the caller. It does not read a file and it does not run a command. Your program bounds the size of a patch from a network. The caller chooses the size of the buffer that holds the patch.

## Limits

- **The diff works on lines.** The package compares whole lines. A change inside a line shows the whole line on each side. Python `difflib`, Node `diff` and Rust `similar` can compare characters, words and sentences. The package does not. A later release may add it.
- **The unified output holds no time stamp.** GNU `diff -u` writes the time of each file into the two header lines. The package writes only the names that the caller gives.
- **The diff of two texts may differ from the diff of GNU**. The reference libraries pick different anchors when more than one diff is minimal. GNU `diff` skips the search when it thinks the cost is too high. So its diff is not always minimal. The package always gives a minimal diff, unless the rule `max_edits` stops the search first.
- **The apply of a patch works on one file at a time**. A patch of many files needs one call per file. The call takes the index of the file.
- **The read of a patch takes no limit of bytes**. The count of files and the count of hunks are bounded. The size of the patch is not. Your program bounds the size of a patch from a network.
- **The apply takes the same text that the read took**. The call holds the patch bytes apart from the parsed places. Give it the text that `patch_parse` read. Another text holds places that do not fit.
- **The apply does not create or remove a file.** A patch that adds or removes a file gives `ERR_NO_MATCH`. The package does not touch a file of the file system.
- **The patch reads no binary diff.** The package reads the unified format only. The Git binary format, and the format of `diff -u` with the `--binary` rule, stay out.
- **The patch holds no other text.** A line before the first file header is skipped. A patch with a text of its own is not read.
- **A hunk finds its place by its content.** The apply searches outward from the place of the header. A hunk that matches at many places takes the first one that fits.
- **The rules of a diff hold no junk**. Python `difflib` treats a line that appears often as junk, and drops it from the comparison. The package never drops a line.