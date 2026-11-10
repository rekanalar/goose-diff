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
import matcher;
import tokens;
import context;
import cssdiff;
import inline;
import compact;
import algos;
import spatch;
import spatchapply;
import converts;
import htmldiff;
import jsondiff;
import ndiff;

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
    if code == ERR_BAD_JSON { return "the text is not JSON"; }
    if code == ERR_BAD_TEXT { return "a text holds the byte 0 or the byte 1"; }
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
    // The search of the diff: ALG_MYERS, ALG_RO, ALG_PATIENCE, ALG_LCS or ALG_MYERS_SPLIT.
    algorithm: i64,
    // The junk rule of the matcher and of the line search of a delta:
    // JUNK_NONE, JUNK_BLANK or JUNK_COMMENT.
    junk: i64,
    // The popular rule of the matcher. It drops a line that appears
    // often in the second text.
    autojunk: bool,
    // The most compares that the search spends.
    max_work: i64,
    // The carriage return before a line feed does not matter.
    strip_trailing_cr: bool,
    // The most lines of the two texts. Past it, the call is a fault.
    max_tokens: i64,
    // The junk characters of a delta: CHARJUNK_BLANK or CHARJUNK_NONE.
    char_junk: i64,
}

// default_options gives 3 lines of context, 2000 edits and 16 MiB.
fn default_options() -> Options {
    return Options { context: 3, max_edits: 2000, max_input: 16777216,
                     algorithm: ALG_MYERS, junk: JUNK_NONE, autojunk: true,
                     max_work: 50000000, strip_trailing_cr: false,
                     max_tokens: 2000000, char_junk: CHARJUNK_BLANK };
}

// The most context lines that one call takes. A larger value would wrap
// the arithmetic of the hunk grouping.
const MAX_CONTEXT: i64 = 1073741824;

// The most edits that one search takes. The trace of the search holds
// the order of the square of this number of values, so the cap keeps the
// memory of one call at about 36 MB.
const MAX_EDITS: i64 = 3000;

// The most compares that one search spends.
const MAX_WORK: i64 = 500000000;

// The most lines or tokens of the two texts of one call. The lines and
// the tokens hold memory of their own, so the count stays bounded. The
// cap keeps the memory of one call at about 600 MB. The default of two
// million keeps it at about 160 MB.
const MAX_TOKENS: i64 = 8000000;

// search_ok tells whether the rules of a search are in range. The rules
// of the matcher and the rules of a token search share them.
fn search_ok(max_edits: i64, max_input: i64, algorithm: i64, max_work: i64,
             max_tokens: i64) -> bool {
    return max_edits >= 1 && max_edits <= MAX_EDITS && max_input >= 0 &&
           (algorithm >= ALG_MYERS && algorithm <= ALG_MYERS_SPLIT) &&
           max_work >= 0 && max_work <= MAX_WORK &&
           max_tokens >= 1 && max_tokens <= MAX_TOKENS;
}

// options_ok tells whether the options are in range.
fn options_ok(o: Options) -> bool {
    return o.context >= 0 && o.context <= MAX_CONTEXT &&
           o.junk >= JUNK_NONE && o.junk <= JUNK_COMMENT &&
           o.char_junk >= CHARJUNK_BLANK && o.char_junk <= CHARJUNK_NONE &&
           search_ok(o.max_edits, o.max_input, o.algorithm, o.max_work, o.max_tokens);
}

// lines_of splits two texts into lines and gives an id to every line.
// The count of the lines stays under the limit. It gives a code.
fn lines_of(a: const u8[:], b: const u8[:], la: Span[>..]&, lb: Span[>..]&,
            ida: i32[>..]&, idb: i32[>..]&, o: Options) -> i64 {
    split_lines(a, la);
    split_lines(b, lb);
    if la.len + lb.len > o.max_tokens { return ERR_TOO_LARGE; }
    intern(a, la[..], b, lb[..], ida, idb,
           Compare { fold: false, strip_cr: o.strip_trailing_cr });
    return ERR_OK;
}

// diff_lines adds the opcodes of a against b to `ops`, line by line. It
// gives a code and a flag. The flag is true when the diff is minimal.
// The rule `algorithm` names the search.
fn diff_lines(a: const u8[:], b: const u8[:], o: Options, ops: Op[>..]&) -> i64, bool {
    if !options_ok(o) { return ERR_BAD_OPTION, false; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE, false; }
    var la: Span[>..] = [];
    var lb: Span[>..] = [];
    var ida: i32[>..] = [];
    var idb: i32[>..] = [];
    if o.algorithm == ALG_RO {
        var junk: u8[>..] = [];
        let pcode = ro_prepare(a, b, o, la, lb, ida, idb, junk);
        if pcode != ERR_OK { return pcode, false; }
        return ro_ops(ida[..], idb[..], junk[..], o.autojunk, o.max_work, ops);
    }
    let code = lines_of(a, b, la, lb, ida, idb, o);
    if code != ERR_OK { return code, false; }
    let acode, exact = diff_ids_alg(ida[..], idb[..], o.algorithm, o.max_edits, o.max_work, ops);
    if acode != ERR_OK { return acode, false; }
    return ERR_OK, exact;
}

// output_ops splits two texts into lines and finds the opcodes that the
// writers of the unified and the context output need. It gives a code and
// the minimality flag.
fn output_ops(a: const u8[:], b: const u8[:], o: Options, la: Span[>..]&, lb: Span[>..]&,
              ops: Op[>..]&) -> i64, bool {
    var ida: i32[>..] = [];
    var idb: i32[>..] = [];
    var exact = false;
    if o.algorithm == ALG_RO {
        var junk: u8[>..] = [];
        let pcode = ro_prepare(a, b, o, la, lb, ida, idb, junk);
        if pcode != ERR_OK { return pcode, false; }
        let code, minimal = ro_ops(ida[..], idb[..], junk[..], o.autojunk, o.max_work, ops);
        if code != ERR_OK { return code, false; }
        exact = minimal;
    } else {
        let code = lines_of(a, b, la, lb, ida, idb, o);
        if code != ERR_OK { return code, false; }
        let acode, minimal = diff_ids_alg(ida[..], idb[..], o.algorithm, o.max_edits, o.max_work, ops);
        if acode != ERR_OK { return acode, false; }
        exact = minimal;
    }
    return ERR_OK, exact;
}

// unified_diff appends the unified diff of a against b to `out`. The
// names go in the two header lines. Equal texts give no output. It gives
// a code and a flag. The flag is true when the diff is minimal. The rule
// `algorithm` names the search.
fn unified_diff(out: u8[>..]&, a: const u8[:], b: const u8[:], a_name: const u8[:], b_name: const u8[:],
                o: Options) -> i64, bool {
    return unified_diff_dated(out, a, b, a_name, b_name, "", "", "\n", o);
}

// unified_diff_dated is unified_diff with the dates of the two files and
// the line terminator of the header lines, as the `fromfiledate`,
// `tofiledate` and `lineterm` of Python. A date that is not empty follows
// its name after a tab. The terminator holds the bytes 10 and 13 only,
// two at most. A date with a line end is a fault.
fn unified_diff_dated(out: u8[>..]&, a: const u8[:], b: const u8[:], a_name: const u8[:],
                      b_name: const u8[:], a_date: const u8[:], b_date: const u8[:],
                      lineterm: const u8[:], o: Options) -> i64, bool {
    if !options_ok(o) || !lineterm_ok(lineterm) { return ERR_BAD_OPTION, false; }
    if a.len > o.max_input || b.len > o.max_input { return ERR_TOO_LARGE, false; }
    if !name_ok(a_name) || !name_ok(b_name) || !name_ok(a_date) || !name_ok(b_date) { return ERR_BAD_NAME, false; }
    var la: Span[>..] = [];
    var lb: Span[>..] = [];
    var ops: Op[>..] = [];
    let code, exact = output_ops(a, b, o, la, lb, ops);
    if code != ERR_OK { return code, false; }
    write_unified(out, a, la[..], b, lb[..], ops[..], a_name, b_name, a_date, b_date, lineterm, o.context);
    return ERR_OK, exact;
}
