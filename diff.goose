// diff - text diff, unified patches and patch apply for Goose.
//
// The references are the Python library difflib, the Node library diff
// (jsdiff), the Rust crate similar and the Go library go-difflib.
//
// A call that can fail gives a code. The code ERR_OK means that the call
// succeeded. A call that fails leaves the buffer of the caller as it was.
//
// The repository is goose-diff. The import name is "diff".
namespace diff;

import std;
import lines;
import myers;
import unified;
import patch;

// The codes of the faults.
const ERR_OK: i64 = 0;
const ERR_TOO_LARGE: i64 = 1;
const ERR_BAD_OPTION: i64 = 2;

// error_text names a code.
fn error_text(code: i64) -> const u8[:] {
    if code == ERR_OK { return "ok"; }
    if code == ERR_TOO_LARGE { return "an input is larger than the limit"; }
    if code == ERR_BAD_OPTION { return "an option is out of range"; }
    if code == ERR_BAD_NAME { return "a file name holds a line end"; }
    if code == ERR_BAD_PATCH { return "the patch is not a valid unified patch"; }
    if code == ERR_NO_MATCH { return "a hunk matches no place in the text"; }
    if code == ERR_TOO_MUCH_WORK { return "the search for a hunk took too much work"; }
    if code == ERR_NO_FILE { return "the patch holds no such file"; }
    return "unknown code";
}

// Options holds the rules of a diff.
struct Options {
    // The lines of context around a change in the unified output.
    context: i64,
    // The most edits that the search takes. A larger count costs memory
    // of the order of its square. Past it, the diff is valid, not minimal.
    max_edits: i64,
    // The most bytes of one input.
    max_input: i64,
}

// default_options gives 3 lines of context, 2000 edits and 16 MiB.
fn default_options() -> Options {
    return Options { context: 3, max_edits: 2000, max_input: 16777216 };
}

// The most context lines that one call takes. A larger value would wrap
// the arithmetic of the hunk grouping.
const MAX_CONTEXT: i64 = 1073741824;

// The most edits that one search takes. The trace of the search holds
// the order of the square of this number of values, so the cap keeps the
// memory of one call at about 36 MB.
const MAX_EDITS: i64 = 3000;

// options_ok tells whether the options are in range.
fn options_ok(o: Options) -> bool {
    return o.context >= 0 && o.context <= MAX_CONTEXT &&
           o.max_edits >= 1 && o.max_edits <= MAX_EDITS && o.max_input >= 0;
}

// lines_of splits two texts into lines and gives an id to every line.
fn lines_of(a: const u8[:], b: const u8[:], la: Span[>..]&, lb: Span[>..]&,
            ida: i32[>..]&, idb: i32[>..]&) {
    split_lines(a, la);
    split_lines(b, lb);
    intern(a, la[..], b, lb[..], ida, idb);
}

// diff_lines adds the opcodes of a against b to `ops`, line by line. It
// gives a code and a flag. The flag is true when the diff is minimal.
fn diff_lines(a: const u8[:], b: const u8[:], o: Options, ops: Op[>..]&) -> i64, bool {
    if !options_ok(o) { return ERR_BAD_OPTION, false; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE, false; }
    var la: Span[>..] = [];
    var lb: Span[>..] = [];
    var ida: i32[>..] = [];
    var idb: i32[>..] = [];
    lines_of(a, b, la, lb, ida, idb);
    let exact = diff_ids(ida[..], idb[..], o.max_edits, ops);
    return ERR_OK, exact;
}

// unified_diff appends the unified diff of a against b to `out`. The
// names go in the two header lines. Equal texts give no output. It gives
// a code and a flag. The flag is true when the diff is minimal.
fn unified_diff(out: u8[>..]&, a: const u8[:], b: const u8[:], a_name: const u8[:], b_name: const u8[:],
                o: Options) -> i64, bool {
    if !options_ok(o) { return ERR_BAD_OPTION, false; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE, false; }
    if !name_ok(a_name) || !name_ok(b_name) { return ERR_BAD_NAME, false; }
    var la: Span[>..] = [];
    var lb: Span[>..] = [];
    var ida: i32[>..] = [];
    var idb: i32[>..] = [];
    lines_of(a, b, la, lb, ida, idb);
    var ops: Op[>..] = [];
    let exact = diff_ids(ida[..], idb[..], o.max_edits, ops);
    write_unified(out, a, la[..], b, lb[..], ops[..], a_name, b_name, o.context);
    return ERR_OK, exact;
}
