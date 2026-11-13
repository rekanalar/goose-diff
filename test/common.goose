// The helpers that the tests of more than one group share.
namespace common;

import std;
import diff from "..";
import unicode from "rekanalar/goose-unicode@v0.3.0";

var seed: u64 = 12345;

fn rnd(n: i64) -> i64 {
    seed = seed * 6364136223846793005 + 1442695040888963407;
    return ((seed >> 33) as i64) % n;
}

// make_text builds a text of n lines drawn from `alpha` distinct lines.
fn make_text(out: u8[>..]&, n: i64, alpha: i64) {
    for i in n {
        out.push('a' + rnd(alpha) as! u8);
        if rnd(7) == 0 { out.push('b'); }
        if i + 1 < n || rnd(2) == 0 { out.push(10); }
    }
}

// lcs_len gives the length of the longest common subsequence of lines.
fn lcs_len(a: const u8[:], b: const u8[:]) -> i64 {
    var la: diff::Span[>..] = [];
    var lb: diff::Span[>..] = [];
    diff::split_lines(a, la);
    diff::split_lines(b, lb);
    var prev: i64[>..] = [];
    var cur: i64[>..] = [];
    prev.resize(lb.len + 1, 0);
    cur.resize(lb.len + 1, 0);
    for i in la.len {
        cur[0] = 0;
        for j in lb.len {
            if diff::span_equal(a, la[i], b, lb[j], diff::Compare { fold: false, strip_cr: false }) {
                cur[j + 1] = prev[j] + 1;
            } else if prev[j + 1] >= cur[j] {
                cur[j + 1] = prev[j + 1];
            } else {
                cur[j + 1] = cur[j];
            }
        }
        for j in lb.len + 1 { prev[j] = cur[j]; }
    }
    return prev[lb.len];
}

// check_ops tests that the opcodes tile both inputs, that the equal
// ranges hold equal lines, and gives the count of equal lines.
fn check_ops(a: const u8[:], b: const u8[:], ops: const diff::Op[:]) -> i64 {
    var la: diff::Span[>..] = [];
    var lb: diff::Span[>..] = [];
    diff::split_lines(a, la);
    diff::split_lines(b, lb);
    var ai: i64 = 0;
    var bi: i64 = 0;
    var equal: i64 = 0;
    for o in ops {
        assert(o.a_lo == ai && o.b_lo == bi);
        assert(o.a_hi >= o.a_lo && o.b_hi >= o.b_lo);
        if o.tag == diff::OP_EQUAL {
            assert(o.a_hi - o.a_lo == o.b_hi - o.b_lo && o.a_hi > o.a_lo);
            for k in o.a_hi - o.a_lo {
                assert(diff::span_equal(a, la[o.a_lo + k], b, lb[o.b_lo + k], diff::Compare { fold: false, strip_cr: false }));
            }
            equal = equal + (o.a_hi - o.a_lo);
        } else if o.tag == diff::OP_DELETE {
            assert(o.a_hi > o.a_lo && o.b_hi == o.b_lo);
        } else if o.tag == diff::OP_INSERT {
            assert(o.b_hi > o.b_lo && o.a_hi == o.a_lo);
        } else {
            assert(o.tag == diff::OP_REPLACE && o.a_hi > o.a_lo && o.b_hi > o.b_lo);
        }
        ai = o.a_hi;
        bi = o.b_hi;
    }
    assert(ai == la.len && bi == lb.len);
    return equal;
}

// apply_text parses a patch and applies its first file to src.
fn apply_text(src: const u8[:], patch: const u8[:], reverse: bool, out: u8[>..]&) -> i64 {
    var files: diff::FilePatch[>..] = [];
    var hunks: diff::Hunk[>..] = [];
    var body: diff::Span[>..] = [];
    let code = diff::patch_parse(patch, files, hunks, body);
    if code != diff::ERR_OK { return code; }
    var o = diff::default_apply_options();
    o.reverse = reverse;
    return diff::patch_apply(src, patch, files[..], hunks[..], body[..], 0, o, out);
}

// ro_options gives the rules of the Ratcliff-Obershelp matcher.
fn ro_options() -> diff::Options {
    var o = diff::default_options();
    o.algorithm = diff::ALG_RO;
    return o;
}

// clear_changes empties the list of changes.
fn clear_changes(changes: diff::Change[>..]&) {
    changes.resize(0, diff::Change { at: 0, len: 0, count: 0, text: 0, added: false, removed: false });
}

// check_change tells whether a change holds the given values. The text
// of a change says which text it comes from.
fn check_change(c: diff::Change, at: i64, len: i64, count: i64, text: i64,
                added: bool, removed: bool) -> bool {
    return c.at == at && c.len == len && c.count == count && c.text == text &&
           c.added == added && c.removed == removed;
}

// nd_run runs ndiff and gives the code.
fn nd_run(a: const u8[:], b: const u8[:], o: diff::Options, out: u8[>..]&) -> i64 {
    return diff::ndiff(a, b, o, out);
}

// change_text gives the text of a change from the text that holds it.
fn change_text(c: diff::Change, a: const u8[:], b: const u8[:]) -> const u8[:] {
    if c.text == 1 { return b[c.at..c.at + c.len]; }
    return a[c.at..c.at + c.len];
}

fn json_form(text: const u8[:], out: u8[>..]&) -> i64 {
    return diff::json_canonical(text, diff::default_token_options(), out);
}

// ids_of gives the ids of a list of small numbers.
fn ids_of(v: const i32[:], out: i32[>..]&) {
    for x in v { out.push(x); }
}

// ops_text writes the ops as the Rust crate similar names them.
recursive fn put_n(out: u8[>..]&, v: i64) {
    if v >= 10 { put_n(out, v / 10); }
    out.push('0' + (v % 10) as! u8);
}

fn ops_text(ops: const diff::Op[:], out: u8[>..]&) {
    for o in ops {
        if out.len > 0 { out.push(' '); }
        if o.tag == diff::OP_EQUAL { out.push('e'); put_n(out, o.a_lo); out.push(','); put_n(out, o.b_lo); out.push(','); put_n(out, o.a_hi - o.a_lo); }
        else if o.tag == diff::OP_DELETE { out.push('d'); put_n(out, o.a_lo); out.push(','); put_n(out, o.a_hi - o.a_lo); out.push(','); put_n(out, o.b_lo); }
        else if o.tag == diff::OP_INSERT { out.push('i'); put_n(out, o.a_lo); out.push(','); put_n(out, o.b_lo); out.push(','); put_n(out, o.b_hi - o.b_lo); }
        else { out.push('r'); put_n(out, o.a_lo); out.push(','); put_n(out, o.a_hi - o.a_lo); out.push(','); put_n(out, o.b_lo); out.push(','); put_n(out, o.b_hi - o.b_lo); }
    }
}

fn alg_run(a: const i32[:], b: const i32[:], alg: i64, out: u8[>..]&) -> i64 {
    var ops: diff::Op[>..] = [];
    let code, exact = diff::diff_ids_alg(a, b, alg, 2000, 50000000, ops);
    ops_text(ops[..], out);
    return code;
}

fn put_text(out: u8[>..]&, s: const u8[:]) {
    for c in s { out.push(c); }
}

fn eof_run(a: const u8[:], b: const u8[:], rev: bool) -> bool {
    let o = diff::default_options();
    var sp: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hu: diff::Hunk[>..] = [];
    var nn: u8[>..] = [];
    var mk: u8[>..] = [];
    var bd: u8[>..] = [];
    var ls: diff::Span[>..] = [];
    assert(diff::structured_patch("f", "f", a, b, "", "", o, sp, hu, nn, mk, bd, ls) == diff::ERR_OK);
    var out: u8[>..] = [];
    let ao = diff::default_apply_options();
    if !rev {
        assert(diff::patch_apply_fuzz(a, sp, hu[..], mk[..], bd[..], ls[..], ao, out) == diff::ERR_OK);
        return out[..] == b;
    }
    var fsp: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var fh: diff::Hunk[>..] = [];
    var fn2: u8[>..] = [];
    var fm: u8[>..] = [];
    assert(diff::patch_reverse(sp, hu[..], nn[..], mk[..], fsp, fh, fn2, fm) == diff::ERR_OK);
    assert(diff::patch_apply_fuzz(b, fsp, fh[..], fm[..], bd[..], ls[..], ao, out) == diff::ERR_OK);
    return out[..] == a;
}

fn apply_one(src: const u8[:], p: const u8[:], want: const u8[:]) -> bool {
    var files: diff::FilePatch[>..] = [];
    var hunks: diff::Hunk[>..] = [];
    var body: diff::Span[>..] = [];
    if diff::patch_parse(p, files, hunks, body) != diff::ERR_OK { return false; }
    var out: u8[>..] = [];
    if diff::patch_apply(src, p, files[..], hunks[..], body[..], 0, diff::default_apply_options(), out) != diff::ERR_OK { return false; }
    return out == want;
}

// has tells whether a text holds a part.
fn has(hay: const u8[:], part: const u8[:]) -> bool {
    if part.len > hay.len { return false; }
    var i: i64 = 0;
    while i + part.len <= hay.len {
        if hay[i..i + part.len] == part { return true; }
        i = i + 1;
    }
    return false;
}

// test_dated pins the dates, the terminator and the junk rules of Python 3.14.
// le_apply builds the patch of a against b, then applies it to src with
// the rule of the line ends set to `auto`. It gives the code and the text.
fn le_apply(a: const u8[:], b: const u8[:], src: const u8[:], auto: bool) -> i64, u8[>..] {
    let o = diff::default_options();
    var sp: diff::SPatch = diff::SPatch { old_name: diff::Span { at: 0, len: 0 }, new_name: diff::Span { at: 0, len: 0 }, old_header: diff::Span { at: 0, len: 0 }, new_header: diff::Span { at: 0, len: 0 }, first_hunk: 0, hunks: 0 };
    var hu: diff::Hunk[>..] = [];
    var nn: u8[>..] = [];
    var mk: u8[>..] = [];
    var bd: u8[>..] = [];
    var ls: diff::Span[>..] = [];
    assert(diff::structured_patch("f", "f", a, b, "", "", o, sp, hu, nn, mk, bd, ls) == diff::ERR_OK);
    var ao = diff::default_apply_options();
    ao.auto_line_ends = auto;
    var out: u8[>..] = [];
    let c = diff::patch_apply_fuzz(src, sp, hu[..], mk[..], bd[..], ls[..], ao, out);
    return c, out;
}

// test_jsdiff_options pins the rules ignore_newline_at_eof and
// one_change_per_token against the results of jsdiff.
// unicode_run diffs two texts with the Unicode rules and gives the changes
// as lines of tag, a space and the text.
fn unicode_run(a: const u8[:], b: const u8[:], mode: i64, out: u8[>..]&) {
    var o = diff::default_token_options();
    var ch: diff::Change[>..] = [];
    var code: i64 = 0;
    var ex: bool = false;
    if mode == 1 { o.one_change_per_token = true; o.algorithm = diff::ALG_MYERS_SPLIT; code, ex = diff::diff_unicode_words(a, b, o, ch); }
    else if mode == 2 { o.one_change_per_token = true; o.algorithm = diff::ALG_MYERS_SPLIT; code, ex = diff::diff_graphemes(a, b, o, ch); }
    else if mode == 3 { o.unicode_words = true; code, ex = diff::diff_words(a, b, o, ch); }
    else { o.unicode_case = true; code, ex = diff::diff_words(a, b, o, ch); }
    assert(code == diff::ERR_OK);
    for c in ch {
        var src: const u8[:] = b;
        if c.removed { src = a; }
        if c.added { out.push('+'); } else if c.removed { out.push('-'); } else { out.push('='); }
        out.push(' ');
        for k in c.len { out.push(src[c.at + k]); }
        out.push('|');
    }
}

fn unicode_is(a: const u8[:], b: const u8[:], mode: i64, want: const u8[:]) -> bool {
    var out: u8[>..] = [];
    unicode_run(a, b, mode, out);
    if out.len != want.len { return false; }
    for k in want.len { if out[k] != want[k] { return false; } }
    return true;
}

// il_render writes the inline changes of a against b as lines of text:
// the tag, the two indexes, and the segments. A segment of a changed word
// starts with "!", any other segment starts with ".".
fn il_render(a: const u8[:], b: const u8[:], alg: i64) -> u8[>..] {
    return il_render_u(a, b, alg, false);
}

fn il_render_u(a: const u8[:], b: const u8[:], alg: i64, uni: bool) -> u8[>..] {
    var o = diff::default_options();
    o.algorithm = alg;
    o.unicode_words = uni;
    var ch: diff::InlineChange[>..] = [];
    var sg: diff::InlineSeg[>..] = [];
    assert(diff::inline_changes(a, b, o, ch, sg) == diff::ERR_OK);
    var d: u8[>..] = [];
    for c in ch {
        if c.tag == diff::INL_EQUAL { put_text(d, "="); } else if c.tag == diff::INL_DELETE { put_text(d, "-"); } else { put_text(d, "+"); }
        put_text(d, " ");
        if c.old_index < 0 { put_text(d, "-"); } else { diff::digits_of(d, c.old_index); }
        put_text(d, " ");
        if c.new_index < 0 { put_text(d, "-"); } else { diff::digits_of(d, c.new_index); }
        put_text(d, " ");
        for k in c.count {
            let s = sg[c.first + k];
            if k > 0 { put_text(d, "|"); }
            if s.emph { put_text(d, "!"); } else { put_text(d, "."); }
            var text = a;
            if c.tag == diff::INL_INSERT { text = b; }
            for x in s.len {
                let ch2 = text[s.at + x];
                if ch2 == 10 { put_text(d, "\\n"); } else { d.push(ch2); }
            }
        }
        put_text(d, "\n");
    }
    return d;
}
